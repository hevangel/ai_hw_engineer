#!/usr/bin/env python3
"""Map replay RESULT/FAIL lines to capture-file stems and gate the result.

Usage: summarize_replay.py MANIFEST LOG OUT_JSON [OPEN_JSON]
Exit status is zero only when the failing records are exactly the open
discrepancies listed in OPEN_JSON (by file and test index) that belong to
the replayed files; a new failure or a listed record that now passes both
fail the gate so the list stays exact.
"""
import json
import re
import sys


def main() -> int:
    manifest = json.load(open(sys.argv[1]))
    stems = {f["id"]: f["stem"] for f in manifest["files"]}
    results, failures, failed_ids = {}, {}, set()
    for line in open(sys.argv[2]):
        m = re.match(r"RESULT file (\d+) pass (\d+) fail (\d+)", line)
        if m:
            results[stems[int(m[1])]] = {"pass": int(m[2]), "fail": int(m[3])}
        m = re.match(r"FAIL file (\d+) (.*)", line)
        if m:
            failures.setdefault(stems[int(m[1])], []).append(m[2].strip())
            idx = re.match(r"test (\d+) ", m[2])
            failed_ids.add((stems[int(m[1])], int(idx[1])))
    total_pass = sum(r["pass"] for r in results.values())
    total_fail = sum(r["fail"] for r in results.values())
    files_clean = sum(1 for r in results.values() if r["fail"] == 0)
    summary = {"revision": manifest["revision"], "subset": manifest["subset"],
               "files": len(results), "files_all_pass": files_clean,
               "tests_pass": total_pass, "tests_fail": total_fail,
               "revoked_skipped": manifest["revoked"],
               "failing_files": {k: dict(v, examples=failures.get(k, []))
                                 for k, v in sorted(results.items()) if v["fail"]}}
    json.dump(summary, open(sys.argv[3], "w"), indent=1)
    print(f"{files_clean}/{len(results)} files fully pass; "
          f"{total_pass} pass, {total_fail} fail")
    for k, v in summary["failing_files"].items():
        print(f"  {k}: {v['fail']}/{v['pass'] + v['fail']} fail; {v['examples'][:1]}")
    if len(sys.argv) < 5:
        return 0 if total_fail == 0 else 1
    listed = {(e["file"], e["idx"]) for e in json.load(open(sys.argv[4]))["open"]
              if e["file"] in results}
    reported_all = all(len(failures.get(k, [])) == v["fail"] for k, v in results.items())
    new = failed_ids - listed
    fixed = listed - failed_ids
    summary["open_listed"] = len(listed)
    json.dump(summary, open(sys.argv[3], "w"), indent=1)
    if not reported_all:
        print("GATE FAIL: replay truncated its failure report; rerun with a larger report limit")
        return 1
    if new or fixed:
        print(f"GATE FAIL: {len(new)} unlisted failures, {len(fixed)} listed records now pass")
        for item in sorted(new)[:20]:
            print(f"  new failure {item}")
        for item in sorted(fixed)[:20]:
            print(f"  now passing {item}")
        return 1
    print(f"GATE PASS: all failures are the {len(listed)} listed open discrepancies")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
