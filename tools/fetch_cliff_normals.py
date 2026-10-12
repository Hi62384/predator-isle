"""Fetch only NormalGL JPG entries using ZIP directory and HTTP byte ranges."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import re
import zlib

IDS = ['Rock064','Rock058','Rock051','Rock060','Rock030','Rock061','Rock050','Rocks007','Rocks011']
DEST = Path(__file__).resolve().parents[1] / 'assets/terrain/cliff_normals/ambientcg'

def fetch(asset):
    url = 'https://ambientcg.com/get?file=' + asset + '_2K-JPG.zip'
    headers = subprocess.check_output(['curl.exe','-I','-L','--fail','--silent','--show-error',url]).decode()
    size = int(re.findall(r'(?im)^content-length:\s*(\d+)',headers)[-1])
    final = re.findall(r'(?im)^location:\s*(\S+)',headers)[-1]
    def get(start, end):
        data = subprocess.check_output(['curl.exe','--fail','--silent','--show-error','--max-filesize',str(end-start+1),'--range',f'{start}-{end}',final])
        assert len(data) == end-start+1, 'Server ignored range'
        return data
    tail = get(max(0,size-65557),size-1)
    at = tail.rfind(b'PK\x05\x06')
    assert at >= 0
    eocd = struct.unpack_from('<4s4H2LH',tail,at)
    directory = get(eocd[6],eocd[6]+eocd[5]-1)
    at = 0
    while at < len(directory):
        entry = struct.unpack_from('<4s6H3L5H2L',directory,at)
        assert entry[0] == b'PK\x01\x02'
        name = directory[at+46:at+46+entry[10]].decode('utf8')
        at += 46+entry[10]+entry[11]+entry[12]
        if name.endswith('_NormalGL.jpg'):
            local = get(entry[16],entry[16]+29)
            header = struct.unpack('<4s5H3L2H',local)
            offset = entry[16]+30+header[9]+header[10]
            packed = get(offset,offset+entry[8]-1)
            raw = zlib.decompress(packed,-15) if entry[4] == 8 else packed
            assert len(raw)==entry[9] and zlib.crc32(raw)==entry[7]
            target = DEST / (asset.lower()+'_normal.jpg')
            target.write_bytes(raw)
            print(asset,len(raw),'normal bytes',flush=True)
            return dict(id=asset,source='https://ambientcg.com/view?id='+asset,
                        resolution='2K',original_filename=name,filename=target.name,
                        sha256=hashlib.sha256(raw).hexdigest(),license='CC0',convention='OpenGL +Y',
                        download='HTTP ranges: ZIP metadata and NormalGL entry only')
    raise RuntimeError('NormalGL entry missing: '+asset)

if __name__ == '__main__':
    DEST.mkdir(parents=True,exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        records=list(pool.map(fetch,IDS))
    (DEST/'sources.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf8')
