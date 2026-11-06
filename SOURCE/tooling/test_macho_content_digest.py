"""Pure malformed-input and narrow-normalization checks; no native build."""

import hashlib
from pathlib import Path
import struct
import subprocess
import sys
import unittest

from tooling.macho_content_digest import MachOError, content_digest


def _segment(name=b"__LINKEDIT", filesize=128, vmsize=4096):
    return struct.pack(
        "<II16sQQQQiiII",
        0x19,
        72,
        name.ljust(16, b"\0"),
        0,
        vmsize,
        200,
        filesize,
        7,
        1,
        0,
        0,
    )


def _uuid(value=b"0123456789abcdef"):
    return struct.pack("<II", 0x1B, 24) + value


def _image(commands=None, cpu=0x0100000C):
    if commands is None:
        commands = [_segment(b"__TEXT"), _segment(), _uuid()]
    region = b"".join(commands)
    header = struct.pack(
        "<IIIIIIII", 0xFEEDFACF, cpu, 0, 6, len(commands), len(region), 0, 0
    )
    return header + region + bytes(range(128))


def _u32(data, offset, value):
    result = bytearray(data)
    struct.pack_into("<I", result, offset, value)
    return bytes(result)


def _fat(image=None, cpu=0x0100000C, subtype=0, offset=32, alignment=4, suffix=b""):
    if image is None:
        image = _image()
    header = struct.pack(
        ">IIIIIII", 0xCAFEBABE, 1, cpu, subtype, offset, len(image), alignment
    )
    return header + b"\0" * max(0, offset - len(header)) + image + suffix


def _be_u32(data, offset, value):
    result = bytearray(data)
    struct.pack_into(">I", result, offset, value)
    return bytes(result)


class MachOContentDigestTests(unittest.TestCase):
    def digest(self, data, **kwargs):
        return content_digest(data, expected_size=len(data), **kwargs)

    def test_hashes_all_bytes_except_linkedit_vmsize(self):
        original = _image()
        expected = bytearray(original)
        expected[136:144] = b"\0" * 8
        self.assertEqual(self.digest(original), hashlib.sha256(expected).hexdigest())
        self.assertEqual(original, _image(), "normalization must not mutate input")

    def test_only_reviewed_vmsize_variance_is_ignored(self):
        original = _image()
        changed_size = _image([_segment(b"__TEXT"), _segment(vmsize=8192), _uuid()])
        self.assertEqual(self.digest(original), self.digest(changed_size))
        for offset in (8, 24, 72, 144, 152, 176, 200, len(original) - 1):
            with self.subTest(offset=offset):
                changed = bytearray(original)
                changed[offset] ^= 1
                self.assertNotEqual(self.digest(original), self.digest(bytes(changed)))

    def test_linkedit_filesize_and_fileoff_remain_pinned(self):
        original = _image()
        changed_filesize = _image([_segment(b"__TEXT"), _segment(filesize=4096), _uuid()])
        self.assertNotEqual(self.digest(original), self.digest(changed_filesize))
        changed_fileoff = bytearray(original)
        struct.pack_into("<Q", changed_fileoff, 144, 208)
        self.assertNotEqual(self.digest(original), self.digest(bytes(changed_fileoff)))

    def test_uuid_is_preserved_unless_explicitly_normalized(self):
        first = _image()
        second = _image([_segment(b"__TEXT"), _segment(), _uuid(b"fedcba9876543210")])
        self.assertNotEqual(self.digest(first), self.digest(second))
        self.assertEqual(
            self.digest(first, normalize_uuid=True),
            self.digest(second, normalize_uuid=True),
        )
        expected = bytearray(first)
        expected[136:144] = b"\0" * 8
        expected[184:200] = b"\0" * 16
        self.assertEqual(
            self.digest(first, normalize_uuid=True), hashlib.sha256(expected).hexdigest()
        )

    def test_unknown_well_formed_command_remains_in_digest(self):
        first = _image([_segment(), struct.pack("<II8s", 0x70000001, 16, b"abcdefgh")])
        second = first[:-1] + bytes([first[-1] ^ 1])
        changed_command = bytearray(first)
        changed_command[112] ^= 1
        self.assertNotEqual(self.digest(first), self.digest(second))
        self.assertNotEqual(self.digest(first), self.digest(bytes(changed_command)))

    def test_expected_stripped_size_is_enforced(self):
        data = _image()
        for size in (0, -1, len(data) - 1, len(data) + 1, True):
            with self.subTest(size=size), self.assertRaises(MachOError):
                content_digest(data, expected_size=size)

    def test_rejects_invalid_fat_32_bit_and_swapped_mach_o(self):
        for magic in (0xCAFEBABE, 0xCAFEBABF, 0xBEBAFECA, 0xFEEDFACE, 0xCFFAEDFE):
            with self.subTest(magic=magic), self.assertRaises(MachOError):
                self.digest(_u32(_image(), 0, magic))

    def test_single_arm64_fat32_normalizes_inner_fields_at_absolute_offsets(self):
        data = _fat(offset=16384, alignment=14)
        expected = bytearray(data)
        expected[16384 + 136 : 16384 + 144] = b"\0" * 8
        self.assertEqual(self.digest(data), hashlib.sha256(expected).hexdigest())
        expected[16384 + 184 : 16384 + 200] = b"\0" * 16
        self.assertEqual(
            self.digest(data, normalize_uuid=True), hashlib.sha256(expected).hexdigest()
        )

    def test_fat32_header_padding_and_trailing_bytes_remain_in_digest(self):
        data = _fat(suffix=b"trailing padding")
        for offset in (28, 31, len(data) - 1):
            with self.subTest(offset=offset):
                changed = bytearray(data)
                changed[offset] ^= 1
                self.assertNotEqual(self.digest(data), self.digest(bytes(changed)))
        self.assertNotEqual(self.digest(_fat()), self.digest(_image()))

    def test_fat32_rejects_multiple_other_architecture_and_subtype_mismatch(self):
        for data in (
            _be_u32(_fat(), 4, 0),
            _be_u32(_fat(), 4, 2),
            _fat(cpu=0x01000007),
            _fat(image=_image(cpu=0x01000007)),
            _fat(subtype=1),
        ):
            with self.subTest(header=data[:28]), self.assertRaises(MachOError):
                self.digest(data)

    def test_fat32_rejects_header_overlap_alignment_and_out_of_bounds_slice(self):
        for data in (
            _fat()[:20],
            _be_u32(_fat(), 16, 16),
            _be_u32(_fat(), 16, 30),
            _be_u32(_fat(), 24, 32),
            _be_u32(_fat(), 16, 4096),
            _be_u32(_fat(), 20, 0),
            _be_u32(_fat(), 20, 31),
            _be_u32(_fat(), 20, len(_image()) + 1),
        ):
            with self.subTest(header=data[:28]), self.assertRaises(MachOError):
                self.digest(data)

    def test_fat32_load_commands_must_fit_declared_slice_not_wrapper_tail(self):
        data = _be_u32(_fat(), 20, 64)
        with self.assertRaises(MachOError):
            self.digest(data)

    def test_rejects_wrong_architecture(self):
        for cpu in (0x01000007, 0x0200000C, 12):
            with self.subTest(cpu=cpu), self.assertRaises(MachOError):
                self.digest(_image(cpu=cpu))

    def test_rejects_truncated_header_or_command_region(self):
        data = _image()
        for changed in (data[:16], data[:199], _u32(data, 20, len(data))):
            with self.subTest(length=len(changed)), self.assertRaises(MachOError):
                self.digest(changed)

    def test_rejects_invalid_command_boundaries(self):
        data = _image()
        for size in (0, 4, 12, 512):
            with self.subTest(size=size), self.assertRaises(MachOError):
                self.digest(_u32(data, 36, size))
        for changed in (
            _u32(data, 16, 1000),
            _u32(data, 16, 2),
            _u32(data, 20, 167),
            _u32(data, 20, 176),
        ):
            with self.subTest(header=changed[:32]), self.assertRaises(MachOError):
                self.digest(changed)

    def test_rejects_truncated_or_inconsistent_segment_command(self):
        short = struct.pack("<II", 0x19, 64) + b"\0" * 56
        invalid_sections = _u32(_segment(), 64, 1)
        for command in (short, invalid_sections):
            with self.subTest(command=command), self.assertRaises(MachOError):
                self.digest(_image([command]))

    def test_requires_exactly_one_linkedit(self):
        for commands in ([], [_segment(b"__TEXT")], [_segment(), _segment()]):
            with self.subTest(count=len(commands)), self.assertRaises(MachOError):
                self.digest(_image(commands))

    def test_uuid_must_be_single_and_well_formed(self):
        self.digest(_image([_segment()]))
        with self.assertRaises(MachOError):
            self.digest(_image([_segment()]), normalize_uuid=True)
        duplicate = _image([_segment(), _uuid(), _uuid()])
        for enabled in (False, True):
            with self.subTest(normalize_uuid=enabled), self.assertRaises(MachOError):
                self.digest(duplicate, normalize_uuid=enabled)
        truncated = _image([_segment(), struct.pack("<II8s", 0x1B, 16, b"shortuuid")])
        with self.assertRaises(MachOError):
            self.digest(truncated)

    def test_cli_prints_only_digest_and_never_changes_input(self):
        data = _image()
        helper = Path(__file__).with_name("macho_content_digest.py")
        result = subprocess.run(
            [sys.executable, "-B", str(helper), "--expected-size", str(len(data)), "/dev/stdin"],
            input=data,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.decode(), self.digest(data) + "\n")
        self.assertEqual(result.stderr, b"")
        self.assertEqual(data, _image())

    def test_cli_rejects_bad_input_without_stdout_or_traceback(self):
        data = _image(cpu=0x01000007)
        helper = Path(__file__).with_name("macho_content_digest.py")
        result = subprocess.run(
            [sys.executable, "-B", str(helper), "--expected-size", str(len(data)), "/dev/stdin"],
            input=data,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"Mach-O digest failed:", result.stderr)
        self.assertNotIn(b"Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
