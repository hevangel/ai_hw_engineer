# greaseweazle/codec/ibm/ibm.py
#
# Written & released by Keir Fraser <keir.xen@gmail.com>
#
# This is free and unencumbered software released into the public domain.
# See the file COPYING for more details, or visit <http://unlicense.org>.

from __future__ import annotations
from typing import Any, List, Optional, Union, Tuple

import re
import copy, heapq, struct, functools
import itertools as it
from bitarray import bitarray
from enum import Enum
import crcmod.predefined

from greaseweazle import error
from greaseweazle.codec import codec
from greaseweazle.track import MasterTrack, PLL, PLLTrack
from greaseweazle.flux import Flux, HasFlux

default_revs = 2

def sync(dat, clk=0xc7):
    x = 0
    for i in range(8):
        x <<= 1
        x |= (clk >> (7-i)) & 1
        x <<= 1
        x |= (dat >> (7-i)) & 1
    return bytes(struct.pack('>H', x))

fm_sync_prefix = bitarray(endian='big')
fm_sync_prefix.frombytes(b'\xaa\xaa' + sync(0xf8))
fm_sync_prefix = fm_sync_prefix[:16+10]

fm_iam_sync_bytes = sync(0xfc, 0xd7)
fm_iam_sync = bitarray(endian='big')
fm_iam_sync.frombytes(b'\xaa\xaa' + fm_iam_sync_bytes)

mfm_iam_sync_bytes = b'\x52\x24' * 3
mfm_iam_sync = bitarray(endian='big')
mfm_iam_sync.frombytes(mfm_iam_sync_bytes)

mfm_sync_bytes = b'\x44\x89' * 3
mfm_sync = bitarray(endian='big')
mfm_sync.frombytes(mfm_sync_bytes)

def fm_encode(dat):
    out = bytearray()
    for x in dat:
        if (x & 0xaa) == 0:
            x |= 0xaa
        out.append(x)
    return bytes(out)

def mfm_encode(dat):
    y = 0
    out = bytearray()
    for x in dat:
        y = (y<<8) | x
        if (x & 0xaa) == 0:
            y |= ~((y>>1)|(y<<1)) & 0xaaaa
        y &= 255
        out.append(y)
    return bytes(out)

encode_list: List[int] = []
for x in range(256):
    y = 0
    for i in range(8):
        y <<= 2
        y |= (x >> (7-i)) & 1
    encode_list.append(y)

def encode(dat):
    out = bytearray()
    for x in dat:
        out += struct.pack('>H', encode_list[x])
    return bytes(out)
doubler = encode

decode_list = bytearray(0x5556)
for x in range(0x5556):
    index = x & 0x5555
    y = (index + (index >> 1)) & 0x3333
    y = (y + (y >> 2)) & 0x0F0F
    y = (y + (y >> 4)) & 0x00FF
    decode_list[index] = y

def decode(dat):
    out = bytearray()
