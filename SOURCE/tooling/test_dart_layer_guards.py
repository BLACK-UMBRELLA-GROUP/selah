"""Exercise the Dart-layer command guards through their public shell interface."""

from pathlib import Path
import subprocess
import unittest


GUARDS = Path(__file__).resolve().parent / "no_git"
TOOLCHAIN_BIN = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin"
IPHONEOS_SDK = (
    "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/"
    "Developer/SDKs/iPhoneOS27.2.sdk"
)


class DartLayerGuardTests(unittest.TestCase):
    def run_guard(self, command, *args):
        return subprocess.run(
            [GUARDS / command, *args],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=5,
        )

    def test_git_subprocess_is_blocked(self):
        result = self.run_guard("git", "--version")
        self.assertEqual(result.returncode, 86)
        self.assertEqual(result.stdout, "")
        self.assertIn("blocked an unexpected Git subprocess", result.stderr)

    def test_xcrun_resolves_only_pinned_tool_paths(self):
        tools = ("dsymutil", "strip", "lipo", "install_name_tool", "otool", "clang", "ar", "ld", "cc")
        allowed = [(tool, f"{TOOLCHAIN_BIN}/{tool}") for tool in tools]
        allowed.append(("codesign", "/usr/bin/codesign"))
        for tool, expected in allowed:
            with self.subTest(tool=tool):
                result = self.run_guard("xcrun", "--find", tool)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, f"{expected}\n")
                self.assertEqual(result.stderr, "")

    def test_xcrun_resolves_the_pinned_sdk_in_both_supported_orders(self):
        requests = (
            ("--sdk", "iphoneos", "--show-sdk-path"),
            ("--show-sdk-path", "--sdk", "iphoneos"),
        )
        for request in requests:
            with self.subTest(request=request):
                result = self.run_guard("xcrun", *request)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, f"{IPHONEOS_SDK}\n")
                self.assertEqual(result.stderr, "")

    def test_xcrun_rejects_empty_and_out_of_scope_requests(self):
        requests = (
            ((), "empty xcrun request"),
            (("--find", "xcodebuild"), "unexpected xcrun tool: xcodebuild"),
            (("--sdk", "iphonesimulator", "--show-sdk-path"), "unexpected xcrun tool"),
        )
        for request, diagnostic in requests:
            with self.subTest(request=request):
                result = self.run_guard("xcrun", *request)
                self.assertEqual(result.returncode, 86)
                self.assertEqual(result.stdout, "")
                self.assertIn(diagnostic, result.stderr)
