"""Fetch only the matching official Windows release template from the release ZIP.

HTTP ranges avoid downloading the 1.25 GB collection of unrelated platforms.
Only the exact template filename is extracted. No arbitrary archive paths run.
"""
import binascii
import io
from pathlib import Path
import struct
import urllib.request
import zipfile
import zlib

URL = "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"
SIZE = 1249771228
DEST = Path(__file__).resolve().parents[2] / ".godot" / "export_tools" / "windows_release_x86_64.exe"


def span(start, end):
    request = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{end}", "User-Agent": "PredatorIsle-build/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 206:
            raise RuntimeError(f"Server did not honor bounded range: {response.status}")
        data = response.read(end - start + 2)
    if len(data) != end - start + 1:
        raise RuntimeError("Unexpected range length")
    return data


if DEST.exists():
    raise SystemExit(f"Preserving existing template: {DEST}")
tail = span(SIZE - 65536, SIZE - 1)
index = tail.rfind(b"PK\x05\x06")
if index < 0:
    raise RuntimeError("Missing ZIP directory")
directory_size, directory_offset = struct.unpack_from("<II", tail, index + 12)
directory = span(directory_offset, directory_offset + directory_size - 1)
# A sparse in-memory archive gives ZipFile its central directory without assets.
synthetic = io.BytesIO(directory + tail[index:])
with zipfile.ZipFile(synthetic) as archive:
    matches = [entry for entry in archive.infolist() if entry.filename == "templates/windows_release_x86_64.exe"]
if len(matches) != 1:
    raise RuntimeError("Expected one official Windows release template")
entry = matches[0]
# ZipFile adjusts header_offset when opening a directory-only archive.
position = 0
offset = None
while position < len(directory):
    name_length, extra_length, comment_length = struct.unpack_from("<HHH", directory, position + 28)
    name = directory[position + 46:position + 46 + name_length].decode()
    if name == entry.filename:
        offset = struct.unpack_from("<I", directory, position + 42)[0]
        break
    position += 46 + name_length + extra_length + comment_length
if offset is None:
    raise RuntimeError("Template location missing")
header = span(offset, offset + 29)
if header[:4] != b"PK\x03\x04":
    raise RuntimeError("Invalid local header")
name_length, extra_length = struct.unpack_from("<HH", header, 26)
start = offset + 30 + name_length + extra_length
compressed = span(start, start + entry.compress_size - 1)
data = zlib.decompress(compressed, -15) if entry.compress_type == zipfile.ZIP_DEFLATED else compressed
if len(data) != entry.file_size or binascii.crc32(data) != entry.CRC or data[:2] != b"MZ":
    raise RuntimeError("Template integrity check failed")
DEST.parent.mkdir(parents=True, exist_ok=True)
with DEST.open("xb") as target:
    target.write(data)
print(f"Official template extracted: {DEST} ({len(data)} bytes; ZIP CRC verified)")
