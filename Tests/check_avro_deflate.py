"""Verify TJAXY's Avro deflate block and emit a Python-compressed read fixture.

Usage: python3 Tests/check_avro_deflate.py <tjaxy.avro> <python.avro>
"""
from pathlib import Path
from io import BytesIO
import sys
import zlib


def write_long(value):
    encoded = (value << 1) ^ (value >> 63)
    result = bytearray()
    while encoded > 0x7F:
        result.append((encoded & 0x7F) | 0x80)
        encoded >>= 7
    result.append(encoded)
    return bytes(result)


original = Path(sys.argv[1]).read_bytes()
stream = BytesIO(original)


def read_long():
    value = shift = 0
    while True:
        byte = stream.read(1)[0]
        value |= (byte & 127) << shift
        if not byte & 128:
            return (value >> 1) ^ -(value & 1)
        shift += 7


def read_bytes():
    return stream.read(read_long())


assert stream.read(4) == b'Obj\x01'
count = read_long()
metadata = {}
while count:
    if count < 0:
        count = -count
        read_long()
    for _ in range(count):
        key = read_bytes()
        value = read_bytes()
        metadata[key] = value
    count = read_long()
assert metadata[b'avro.codec'] == b'deflate'
sync = stream.read(16)
assert read_long() == 1
size_offset = stream.tell()
block = read_bytes()
assert stream.read(16) == sync
assert stream.read() == b''
assert zlib.decompress(block, -15) == b'\x02'

compressor = zlib.compressobj(wbits=-15)
independent_block = compressor.compress(b'\x02') + compressor.flush()
Path(sys.argv[2]).write_bytes(
    original[:size_offset] + write_long(len(independent_block)) + independent_block + sync
)
print('Avro raw-deflate wire format and independent read fixture: PASS')
