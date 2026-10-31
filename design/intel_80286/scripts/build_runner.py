#!/usr/bin/env python3
"""Build or reuse the Intel 80286 CPU runner for an exact source/tool fingerprint."""

from contextlib import contextmanager
import copy
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import shlex
import signal
import shutil
import subprocess
import sys
import tempfile
import time


from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
WORK = WORK_ROOT / 'sim'
BINARY_NAME = 'Vintel_80286'
MANIFEST_NAME = 'build_manifest.json'
LOCK_NAME = '.build_runner.lock'
SCHEMA_VERSION = 1
BUILD_FLAGS = (
    '--cc', '--exe', '--build', '-j', '2', '-Wall',
    '--top-module', 'intel_80286',
)
RTL_SUFFIXES = {'.v', '.sv', '.vh', '.svh'}
TB_SUFFIXES = {'.h', '.cpp'}
BUILD_ENVIRONMENT_KEYS = (
    'CC', 'CXX', 'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS',
    'MAKEFLAGS', 'VERILATOR_ROOT',
)


@dataclass(frozen=True)
class BuildResult:
    binary: Path
    fingerprint: str
    reused: bool


def _command_words(value, fallback, search_path=None):
    words = shlex.split(value or fallback, posix=(os.name != 'nt'))
    if not words:
        raise ValueError('Tool command cannot be empty')
    executable = shutil.which(words[0], path=search_path)
    if executable:
        words[0] = executable
    return words


def _version(command, name, environment=None):
    result = subprocess.run([
        *command, '--version'], capture_output=True, text=True,
        timeout=30, env=environment)
    output = (result.stdout + result.stderr).strip()
    if result.returncode:
        raise RuntimeError(f'Could not read {name} version: {output}')
    return output


def _stop_builder_process(process):
    """Terminate and reap Verilator plus make/compiler descendants before unlock."""
    if os.name == 'posix':
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    elif process.poll() is None:
        process.terminate()
    try:
        output = process.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        if os.name == 'posix':
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        elif process.poll() is None:
            process.kill()
        output = process.communicate()
    if os.name == 'posix':
        # Some build descendants can close inherited stdout/stderr before they
        # exit. Kill any stragglers in the session before releasing the lock.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    return output


def _run_builder_process(command, *, cwd, env, timeout,
                         capture_output=True, text=True):
    """Run one build process group and clean up descendants on interruption."""
    if not capture_output or not text:
        raise ValueError('CPU runner builds require captured text output')
    process = subprocess.Popen(
        command, cwd=cwd, env=env, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, start_new_session=(os.name == 'posix'))
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired as error:
        stdout, stderr = _stop_builder_process(process)
        error.stdout = stdout
        error.stderr = stderr
        raise
    except BaseException:
        _stop_builder_process(process)
        raise
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def detect_toolchain(environment=None):
    environment = os.environ if environment is None else environment
    search_path = environment.get('PATH')
    verilator_command = _command_words(
        environment.get('VERILATOR'), 'verilator', search_path)
    compiler_command = _command_words(
        environment.get('CXX', '').strip(), 'g++', search_path)
    return {
        'verilator': {
            'command': verilator_command,
            'version': _version(verilator_command, 'Verilator', environment),
        },
        'compiler': {
            'command': compiler_command,
            'version': _version(compiler_command, 'C++ compiler', environment),
        },
    }


def _input_files(root):
    src_dir = root / 'src'
    tb_dir = root / 'tb'
    if not src_dir.is_dir() or not tb_dir.is_dir():
        raise FileNotFoundError(f'Expected src/ and tb/ under {root}')
    files = [
        path for path in src_dir.rglob('*')
        if path.is_file() and path.suffix.lower() in RTL_SUFFIXES
    ]
    files.extend(
        path for path in tb_dir.rglob('*')
        if path.is_file() and path.suffix.lower() in TB_SUFFIXES
    )
    files.sort(key=lambda path: path.relative_to(root).as_posix())
    if not any(path.suffix.lower() in {'.sv', '.v'} for path in files):
        raise FileNotFoundError(f'No Verilog or SystemVerilog source files under {src_dir}')
    if not (tb_dir / 'bootstrap.cpp').is_file():
        raise FileNotFoundError(f'Missing CPU runner source: {tb_dir / "bootstrap.cpp"}')
    return files


def _source_records(root):
    records = []
    for path in _input_files(root):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        records.append({
            'path': path.relative_to(root).as_posix(),
            'sha256': digest,
        })
    return records


def _build_environment(environment=None):
    source = os.environ if environment is None else environment
    return {key: source.get(key) for key in BUILD_ENVIRONMENT_KEYS}


def _forced_environment(environment=None):
    """Force make to rebuild generated code and objects regardless of mtimes."""
    result = dict(os.environ if environment is None else environment)
    makeflags = result.get('MAKEFLAGS', '') or ''
    try:
        tokens = shlex.split(makeflags, posix=(os.name != 'nt'))
    except ValueError as error:
        raise ValueError(f'Invalid MAKEFLAGS value: {makeflags!r}') from error
    if '-B' not in tokens:
        result['MAKEFLAGS'] = (makeflags + ' -B').strip()
    return result


def _command_for(root, work, toolchain, flags):
    rtl_files = [
        path for path in _input_files(root)
        if path.parent == root / 'src' or (root / 'src') in path.parents
        if path.suffix.lower() in {'.sv', '.v'}
    ]
    rtl_files.sort(key=lambda path: path.relative_to(root).as_posix())
    verilator_command = toolchain['verilator']['command']
    return [
        *verilator_command, *flags,
        '--Mdir', str(work.resolve()),
        *(str(path.resolve()) for path in rtl_files),
        str((root / 'tb/bootstrap.cpp').resolve()),
    ]


def _fingerprint_plan(root, work, toolchain, flags=BUILD_FLAGS, environment=None):
    flags = list(flags)
    plan = {
        'schema_version': SCHEMA_VERSION,
        'sources': _source_records(root),
        'toolchain': copy.deepcopy(toolchain),
        'flags': flags,
        'environment': _build_environment(environment),
        'make_policy': {
            'forced_makeflags': ['-B'],
            'reason': 'Source content may change while mtimes are restored or preserved.',
        },
        'command': _command_for(root, work, toolchain, flags),
    }
    encoded = json.dumps(
        plan, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
    return plan, hashlib.sha256(encoded).hexdigest()


def _sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def _manifest_matches(manifest_path, binary, fingerprint):
    if not binary.is_file() or binary.stat().st_size == 0:
        return False
    try:
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return False
    return (
        manifest.get('schema_version') == SCHEMA_VERSION
        and manifest.get('fingerprint') == fingerprint
        and manifest.get('binary') == binary.name
        and manifest.get('binary_sha256') == _sha256(binary)
    )


def _write_manifest_atomically(manifest_path, value):
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(
        prefix=manifest_path.name + '.', suffix='.tmp', dir=manifest_path.parent)
    temp_path = Path(temp_name)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_path, manifest_path)
        if os.name == 'posix':
            directory_fd = os.open(manifest_path.parent, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
    finally:
        try:
            temp_path.unlink()
        except FileNotFoundError:
            pass


@contextmanager
def _build_lock(lock_path):
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a+b') as stream:
        if os.name == 'nt':
            import msvcrt

            stream.seek(0, os.SEEK_END)
            if stream.tell() == 0:
                stream.write(b'\0')
                stream.flush()
            while True:
                try:
                    stream.seek(0)
                    msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
                    break
                except OSError:
                    time.sleep(0.05)
            try:
                yield
            finally:
                stream.seek(0)
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl

            fcntl.flock(stream.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(stream.fileno(), fcntl.LOCK_UN)


def build_or_reuse(root=ROOT, work=WORK, *, runner=None, toolchain=None,
                   toolchain_provider=None, flags=BUILD_FLAGS, environment=None):
    root = Path(root).resolve()
    work = Path(work).resolve()
    work.mkdir(parents=True, exist_ok=True)
    runner = _run_builder_process if runner is None else runner

    with _build_lock(work / LOCK_NAME):
        build_environment = _forced_environment(environment)

        def current_toolchain(for_environment):
            if toolchain_provider is not None:
                return toolchain_provider(for_environment)
            if toolchain is not None:
                return copy.deepcopy(toolchain)
            return detect_toolchain(for_environment)

        active_toolchain = current_toolchain(build_environment)
        plan, fingerprint = _fingerprint_plan(
            root, work, active_toolchain, flags=flags, environment=build_environment)
        binary = work / BINARY_NAME
        manifest_path = work / MANIFEST_NAME
        if _manifest_matches(manifest_path, binary, fingerprint):
            verification_environment = _forced_environment(environment)
            verification_toolchain = current_toolchain(verification_environment)
            _, verification_fingerprint = _fingerprint_plan(
                root, work, verification_toolchain, flags=flags,
                environment=verification_environment)
            if (verification_fingerprint == fingerprint and
                    _manifest_matches(manifest_path, binary, verification_fingerprint)):
                return BuildResult(binary, fingerprint, True)
            build_environment = verification_environment
            active_toolchain = verification_toolchain
            plan, fingerprint = _fingerprint_plan(
                root, work, active_toolchain, flags=flags,
                environment=build_environment)

        # A failed or interrupted build must never leave an old manifest that
        # could bless a partially replaced executable on the next invocation.
        try:
            manifest_path.unlink()
        except FileNotFoundError:
            pass
        # Never allow a successful no-op or interrupted build to bless the old
        # executable. This is the one expected output file, removed under lock.
        try:
            binary.unlink()
        except FileNotFoundError:
            pass

        command = plan['command']
        try:
            result = runner(
                command, cwd=root, capture_output=True, text=True, timeout=900,
                env=build_environment)
        except subprocess.TimeoutExpired as error:
            output = ''
            if error.stdout:
                output += error.stdout if isinstance(error.stdout, str) else error.stdout.decode(errors='replace')
            if error.stderr:
                output += error.stderr if isinstance(error.stderr, str) else error.stderr.decode(errors='replace')
            (work / 'build.log').write_text(output, encoding='utf-8')
            raise RuntimeError(f'Verilator build timed out; see {work / "build.log"}') from error

        output = (result.stdout or '') + (result.stderr or '')
        (work / 'build.log').write_text(output, encoding='utf-8')
        if result.returncode:
            raise RuntimeError(
                f'Verilator build failed with exit code {result.returncode}; '
                f'see {work / "build.log"}')
        if not binary.is_file() or binary.stat().st_size == 0:
            raise RuntimeError(
                f'Verilator returned success but did not produce {binary}')

        # Inputs may be edited while Verilator or make runs. Recheck source
        # bytes, tool versions, command flags, and the build environment before
        # recording a manifest for the executable.
        try:
            verification_environment = _forced_environment(environment)
            verification_toolchain = current_toolchain(verification_environment)
            _, verification_fingerprint = _fingerprint_plan(
                root, work, verification_toolchain, flags=flags,
                environment=verification_environment)
        except Exception as error:
            try:
                binary.unlink()
            except FileNotFoundError:
                pass
            raise RuntimeError(
                'CPU runner inputs could not be rechecked after the build; '
                'discarded the executable') from error
        if verification_fingerprint != fingerprint:
            try:
                binary.unlink()
            except FileNotFoundError:
                pass
            raise RuntimeError(
                'CPU runner inputs changed during the build; discarded the executable')

        manifest = {
            'schema_version': SCHEMA_VERSION,
            'fingerprint': fingerprint,
            'build_plan': plan,
            'binary': binary.name,
            'binary_sha256': _sha256(binary),
        }
        _write_manifest_atomically(manifest_path, manifest)
        return BuildResult(binary, fingerprint, False)


def main():
    try:
        result = build_or_reuse()
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(f'ERROR: CPU runner build failed: {error}', file=sys.stderr)
        return 1
    action = 'reused verified' if result.reused else 'built'
    print(f'PASS: {action} CPU runner {result.binary} [{result.fingerprint[:12]}]')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
