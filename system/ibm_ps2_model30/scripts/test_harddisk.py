#!/usr/bin/env python3
"""Install original PC DOS with original FDISK/FORMAT, then boot its fixed disk.

No prepared partition/filesystem, BIOS patches, host CPU service or injected
registers: all guest changes pass through the RTL DBA controller and DMA3.
"""
import json
import re
from historical_machine import HistoricalMachine, ROOT
from test_software import disk_file, prompt
from hdd_fat import files, partition


def boot_installed(machine):
    """Cold boot the guest-created disk, including normal DOS first-run input."""
    fixed_prompt=lambda text:bool(re.search(r'C(?:\\)?>$',text.rstrip()))
    machine.command('EJECT 0');machine.command('RESET')
    machine.wait(lambda s,t,h:s['dma']>16384 and
        ('Enter new date' in t or fixed_prompt(t)),
        'original DOS fixed-disk bootstrap, floppy ejected',300000000)
    if not fixed_prompt(machine.text()):
        machine.type('\r')
        machine.wait(lambda s,t,h:'Enter new time' in t or fixed_prompt(t),
            'fixed-disk DOS accepts configured date')
        if not fixed_prompt(machine.text()):machine.type('\r')
    machine.wait(lambda s,t,h:s['keysQueued']==0 and fixed_prompt(t),
        'fixed-disk COMMAND.COM prompt')
    assert machine.state['postErrors']==0 and machine.state['mediaReads']==0
    assert machine.state['hardDiskReads']>0
    machine.type('check c:\r')
    machine.wait(lambda s,t,h:s['keysQueued']==0 and fixed_prompt(t) and 'bytes' in h.lower(),
        'execute DOS-copied program from C:',120000000)
    machine.command('PAUSE')
    (ROOT/'work/harddisk_software_final.json').write_text(json.dumps(machine.state))
    print('PASS: original fixed-disk cold boot and copied program execution',flush=True)


def resume_boot():
    """Repeat only boot/input checks using the previous original-DOS install.

    The bundle must already contain DOS's actual installed file bytes. This
    mode never creates a partition or filesystem on the host.
    """
    bundle=ROOT/'work/historical-harddisk.m30'
    image=bundle.read_bytes()
    assert image[:8]==b'M30DISK1'
    actual=files(image[8:8+21307392])
    floppy=(ROOT/'work/reference/pcdos330.img').read_bytes()
    for installed,original in [(b'IBMBIO  COM',b'IBMBIO  COM'),
        (b'IBMDOS  COM',b'IBMDOS  COM'),(b'COMMAND COM',b'COMMAND COM'),
        (b'CHECK   COM',b'CHKDSK  COM')]:
        assert actual[installed]==disk_file(floppy,original)
    machine=HistoricalMachine('harddisk_boot',{
        'IBM_PS2_MODEL30_HDD_PATH':str(bundle),
        'IBM_PS2_MODEL30_NVRAM_PATH':str(ROOT/'work/harddisk_software_rtc.bin')})
    try:boot_installed(machine)
    finally:machine.close()


def main():
    bundle=ROOT/'work/historical-harddisk.m30'
    if bundle.exists():bundle.unlink()
    machine=HistoricalMachine('harddisk_software',{
        'IBM_PS2_MODEL30_HDD_PATH':str(bundle)})
    def wait(predicate,label,limit=60000000):
        return machine.wait(lambda s,t,h:s['keysQueued']==0 and predicate(t,h),label,limit)
    def dos(label):
        wait(lambda t,h:prompt(t),label)
    try:
        wait(lambda t,h:'640KB OK' in t and '161-Set Date and Time' in t and
            'RESUME' in t,'original Model 30-021 cold POST',190000000)
        assert machine.state['postErrors']==1 and machine.state['hardDiskPresent']
        machine.command('KEY 59');machine.command('KEY 187')
        wait(lambda t,h:'Enter new date' in t or prompt(t),'PC DOS installer floppy boot',150000000)
        if not prompt(machine.text()):
            machine.type('10-15-87\r')
            wait(lambda t,h:'Enter new time' in t or prompt(t),'DOS date input')
            if not prompt(machine.text()):machine.type('12:34:56\r')
        dos('original COMMAND.COM')
        machine.type('debug\r')
        wait(lambda t,h:t.rstrip().endswith('-'),'original DEBUG.COM')
        machine.type('a100\rmov ah,5\rmov cx,1987\rmov dx,1015\rint 1a\r'
            'mov ah,3\rmov cx,1234\rmov dx,5600\rint 1a\rint 20\r\r'
            'g=100\rq\r')
        dos('original BIOS RTC setters')
        assert machine.state['rtc'][9]==0x87
        (ROOT/'work/harddisk_software_rtc.bin').write_bytes(bytes(machine.state['rtc']))
        machine.type('fdisk\r')
        wait(lambda t,h:'FDISK Options' in t and 'Enter choice' in t,
            'original FDISK main menu')
        machine.type('1\r')
        wait(lambda t,h:'Create DOS Partition' in t and 'Enter choice' in t,
            'FDISK create menu')
        machine.type('1\r')
        wait(lambda t,h:'maximum' in t.lower() and ('[Y]' in t or '(Y/N)' in t),
            'FDISK maximum active partition question')
        machine.type('y\r')
        wait(lambda t,h:'restart' in t.lower() and 'Press any key' in t,
            'FDISK writes partition through DMA3',120000000)
        machine.command(f'SAVE 2 {ROOT}/work/harddisk_partitioned.img')
        partition((ROOT/'work/harddisk_partitioned.img').read_bytes())
        writes=machine.state['hardDiskWrites']
        assert writes>0,'FDISK must write through the RTL controller'
        prior_errors=machine.state['postErrors']
        machine.type('\r')
        # FDISK jumps to FFFF:0000 itself; this specifically exercises a
        # running PIT and masked/withdrawn requests during original POST.
        wait(lambda t,h:'Enter new date' in t or prompt(t),
            'FDISK software restart through unchanged BIOS',300000000)
        assert machine.state['postErrors']==prior_errors,'warm POST must add no 102/161 errors'
        if not prompt(machine.text()):
            machine.type('\r')
            wait(lambda t,h:'Enter new time' in t or prompt(t),'restarted DOS date')
            if not prompt(machine.text()):machine.type('\r')
        dos('DOS after FDISK restart')
        machine.type('format c:/s\r')
        wait(lambda t,h:'Proceed with Format (Y/N)?' in t,
            'original FORMAT C:/S warning',100000000)
        machine.type('y\r')
        history=wait(lambda t,h:'Format complete' in h and
            ('Volume label' in t or prompt(t)),
            'FORMAT verifies the full type-26 partition',1200000000)
        if 'Volume label' in machine.text():
            machine.type('MODEL30\r')
            dos('FORMAT volume label and system transfer')
        assert 'System transferred' in history or 'System transferred' in machine.text()
        assert machine.state['hardDiskWrites']>writes
        for command,expected in [('copy chkdsk.com c:check.com\r',r'1 File.*copied'),
                                 ('dir c:\r',r'CHECK\s+COM'),
                                 ('chkdsk c:\r',r'bytes.*available')]:
            machine.type(command)
            wait(lambda t,h:prompt(t) and re.search(expected,h,re.I),
                command.strip(),120000000)
        raw=ROOT/'work/historical-harddisk.img'
        machine.command(f'SAVE 2 {raw}')
        actual=files(raw.read_bytes())
        floppy=(ROOT/'work/reference/pcdos330.img').read_bytes()
        for installed,original in [(b'IBMBIO  COM',b'IBMBIO  COM'),
            (b'IBMDOS  COM',b'IBMDOS  COM'),(b'COMMAND COM',b'COMMAND COM'),
            (b'CHECK   COM',b'CHKDSK  COM')]:
            assert actual[installed]==disk_file(floppy,original),repr(installed)
        print('PASS: independent MBR/FAT16 mirrors/chains and installed file bytes',flush=True)
        boot_installed(machine)
        print('PASS: full original FDISK/FORMAT/SYS/COPY/FAT16/fixed-disk boot regression',flush=True)
    finally:
        (ROOT/'work/harddisk_software_last.json').write_text(json.dumps(machine.state))
        machine.close()


if __name__=='__main__':
    import sys
    if sys.argv[1:]==['--resume-boot']:resume_boot()
    else:
        assert len(sys.argv)==1,'usage: test_harddisk.py [--resume-boot]'
        main()
