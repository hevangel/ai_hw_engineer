#!/usr/bin/env python3
from pathlib import Path
import hashlib, ipaddress, socket
import urllib.parse, urllib.request
ROOT=Path(__file__).resolve().parents[1]
BASE='https://raw.githubusercontent.com/AppleWin/AppleWin/736a12b0a2d59d122ec3d7257497d4ff1fc5c029/resource/'
HOST='raw.githubusercontent.com'
FILES={'Apple2e.rom':('1fb812584c6633fa16b77b20915986ed1178d1e6fc07a647f7ee8d4e6ab9d40b',16384),
       'Apple2e_Enhanced_Video.rom':('52c3b87900ac9399f6525402cab1ccfd8f8259290fc6df54da48fb4c98ae3ed0f',4096)}

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        raise ValueError('redirect refused: '+newurl)

_OPENER=urllib.request.build_opener(_NoRedirect)

def fetch_rom(url):
    # Only the pinned GitHub raw host, resolved up front with non-global
    # addresses refused (DNS-rebinding guard; TLS pins the connection);
    # every artifact is size- and SHA-256-checked before use.
    parsed=urllib.parse.urlsplit(url)
    if parsed.scheme!='https' or parsed.hostname!=HOST:
        raise ValueError('download host not allowed: '+url)
    for info in socket.getaddrinfo(parsed.hostname,443):
        address=ipaddress.ip_address(info[4][0])
        if not address.is_global:
            raise ValueError('resolved address is not global: '+str(address))
    return _OPENER.open(url,timeout=60).read()

work=ROOT/'work'; work.mkdir(exist_ok=True)
for name,(digest,size) in FILES.items():
    path=work/name
    data=path.read_bytes() if path.exists() else fetch_rom(BASE+name)
    if len(data)!=size or hashlib.sha256(data).hexdigest()!=digest:
        raise SystemExit('Firmware checksum/size mismatch: '+name)
    path.write_bytes(data)
    (work/('rom.hex' if name=='Apple2e.rom' else 'font.hex')).write_text(''.join(f'{b:02x}\n' for b in data))
print('PASS pinned original NMOS IIe ROM and external enhanced character representation')
