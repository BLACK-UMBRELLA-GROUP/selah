#!/usr/bin/env python3
"""Hash a stripped arm64 Mach-O, normalizing only reviewed signing variance.

The caller must remove the signature from a disposable copy first. The exact
stripped size is a separate reviewed pin. This helper never changes the input
file and never reads signing identities, profiles, credentials or device data.
A thin image or a big-endian FAT32 wrapper with one arm64 slice is accepted.
"""

import argparse
import hashlib
from pathlib import Path
import struct
import sys
from typing import Optional, Sequence


MH_MAGIC_64 = 0xFEEDFACF
CPU_TYPE_ARM64 = 0x0100000C
LC_SEGMENT_64 = 0x19
LC_UUID = 0x1B
HEADER_SIZE = 32
SEGMENT_SIZE = 72
SECTION_SIZE = 80
UUID_COMMAND_SIZE = 24
LINKEDIT_NAME = b"__LINKEDIT".ljust(16, b"\0")
FAT32_MAGIC = b"\xca\xfe\xba\xbe"
FAT32_HEADER_SIZE = 28


class MachOError(ValueError):
    """The input does not satisfy the reviewed normalization contract."""


def content_digest(
    data: bytes, *, expected_size: int, normalize_uuid: bool = False
) -> str:
    """Return SHA256 after narrowly validated, in-memory normalization.

    Only the eight-byte __LINKEDIT.vmsize field is always zeroed. With
    normalize_uuid=True, exactly one LC_UUID is required and its sixteen UUID
    bytes are also zeroed. UUID bytes remain part of the digest otherwise.
    Every other byte, including headers, commands and payload, is retained.
    """
    if type(expected_size) is not int or expected_size <= 0:
        raise MachOError("expected stripped size must be a positive integer")
    if len(data) != expected_size:
        raise MachOError("stripped Mach-O size does not match its reviewed pin")
    if len(data) < 4:
        raise MachOError("truncated Mach-O header")

    image_start = 0
    image_end = len(data)
    wrapper_subtype = None
    if data[:4] == FAT32_MAGIC:
        if len(data) < FAT32_HEADER_SIZE:
            raise MachOError("truncated FAT32 header or architecture record")
        count, cpu_type, wrapper_subtype, start, size, alignment = struct.unpack_from(
            ">IIIIII", data, 4
        )
        if count != 1:
            raise MachOError("FAT32 wrapper must contain exactly one arm64 slice")
        if cpu_type != CPU_TYPE_ARM64:
            raise MachOError("expected arm64 FAT32 architecture")
        if alignment > 31 or start % (1 << alignment):
            raise MachOError("invalid FAT32 slice alignment")
        if start < FAT32_HEADER_SIZE or size < HEADER_SIZE:
            raise MachOError("FAT32 slice overlaps its header or is too short")
        if start + size > len(data):
            raise MachOError("FAT32 slice extends beyond the input")
        image_start = start
        image_end = start + size
    if image_end - image_start < HEADER_SIZE:
        raise MachOError("truncated Mach-O header")
    magic, cpu_type, cpu_subtype = struct.unpack_from("<III", data, image_start)
    if magic != MH_MAGIC_64:
        raise MachOError("expected a little-endian 64-bit Mach-O image")
    if cpu_type != CPU_TYPE_ARM64:
        raise MachOError("expected arm64 Mach-O architecture")
    if wrapper_subtype is not None and cpu_subtype != wrapper_subtype:
        raise MachOError("FAT32 architecture and inner CPU subtype disagree")
    command_count, commands_size = struct.unpack_from("<II", data, image_start + 16)
    commands_start = image_start + HEADER_SIZE
    commands_end = commands_start + commands_size
    if commands_size % 8 or commands_end > image_end:
        raise MachOError("invalid Mach-O load-command region")
    if command_count > commands_size // 8:
        raise MachOError("load-command count exceeds its declared region")

    linkedit_offsets = []
    uuid_offsets = []
    offset = commands_start
    for _ in range(command_count):
        if offset + 8 > commands_end:
            raise MachOError("truncated Mach-O load command")
        command, size = struct.unpack_from("<II", data, offset)
        if size < 8 or size % 8 or offset + size > commands_end:
            raise MachOError("invalid Mach-O load-command boundary")
        if command == LC_SEGMENT_64:
            if size < SEGMENT_SIZE:
                raise MachOError("truncated LC_SEGMENT_64")
            section_count = struct.unpack_from("<I", data, offset + 64)[0]
            if size != SEGMENT_SIZE + SECTION_SIZE * section_count:
                raise MachOError("LC_SEGMENT_64 section count and size disagree")
            if data[offset + 8 : offset + 24] == LINKEDIT_NAME:
                linkedit_offsets.append(offset + 32)
        elif command == LC_UUID:
            if size != UUID_COMMAND_SIZE:
                raise MachOError("invalid LC_UUID size")
            uuid_offsets.append(offset + 8)
        offset += size

    if offset != commands_end:
        raise MachOError("load commands do not fill their declared region")
    if len(linkedit_offsets) != 1:
        raise MachOError("expected exactly one __LINKEDIT segment")
    if len(uuid_offsets) > 1:
        raise MachOError("duplicate LC_UUID commands")
    if normalize_uuid and len(uuid_offsets) != 1:
        raise MachOError("UUID normalization requires exactly one LC_UUID")

    normalized = bytearray(data)
    start = linkedit_offsets[0]
    normalized[start : start + 8] = b"\0" * 8
    if normalize_uuid:
        start = uuid_offsets[0]
        normalized[start : start + 16] = b"\0" * 16
    return hashlib.sha256(normalized).hexdigest()


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-size", required=True, type=int)
    parser.add_argument("--normalize-uuid", action="store_true")
    parser.add_argument("path", type=Path, help="disposable, already stripped copy")
    args = parser.parse_args(argv)
    try:
        data = args.path.read_bytes()
    except OSError:
        print("Mach-O digest failed: input could not be read", file=sys.stderr)
        return 1
    try:
        digest = content_digest(
            data,
            expected_size=args.expected_size,
            normalize_uuid=args.normalize_uuid,
        )
    except MachOError as error:
        print("Mach-O digest failed: " + str(error), file=sys.stderr)
        return 1
    print(digest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
