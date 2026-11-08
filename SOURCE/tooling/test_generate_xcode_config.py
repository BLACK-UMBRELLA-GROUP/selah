"""Exercise the local Xcode configuration CLI with synthetic, offline inputs."""

import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


GENERATOR = Path(__file__).with_name("generate_xcode_config.dart")


def native_dart():
    executable = shutil.which("dart")
    if executable is None:
        raise RuntimeError("An installed Dart SDK is required")
    resolved = Path(executable).resolve()
    cached = resolved.parent / "cache/dart-sdk/bin/dart"
    return cached if cached.is_file() else resolved


class GenerateXcodeConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dart = native_dart()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="selah-xcode-config-")
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.project = root / "draft project"
        self.flutter = root / "flutter cache"
        self.manifest_path = self.flutter / "bin/cache/flutter.version.json"
        self.manifest = {
            "flutterVersion": "3.44.2",
            "channel": "stable",
            "dartSdkVersion": "3.12.2",
            "frameworkRevision": "0123456789abcdef",
            "engineRevision": "fedcba9876543210",
            "repositoryUrl": "https://example.invalid/flutter.git",
        }
        self.pubspec = self.project / "pubspec.yaml"
        self.packages = self.project / ".dart_tool/package_config.json"
        self.framework = self.project / (
            "ios/Flutter/ephemeral/Packages/.packages/FlutterFramework"
        )
        self.output = self.project / "ios/Flutter/Generated.xcconfig"
        self.manifest_path.parent.mkdir(parents=True)
        self.packages.parent.mkdir(parents=True)
        self.framework.mkdir(parents=True)
        self.pubspec.write_text("name: fixture\nversion: 2.3.4+17\n")
        self.packages.write_text('{"configVersion": 2, "packages": []}\n')
        self.write_manifest()

    def write_manifest(self):
        self.manifest_path.write_text(json.dumps(self.manifest))

    def run_cli(self, arguments=None):
        if arguments is None:
            arguments = [str(self.project), str(self.flutter)]
        return subprocess.run(
            [str(self.dart), str(GENERATOR), *arguments],
            cwd=self.temporary.name,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def assert_refused(self, message):
        sentinel = "existing configuration must survive\n"
        self.output.write_text(sentinel)
        result = self.run_cli()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(message, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(self.output.read_text(), sentinel)

    def test_generates_settings_and_decodable_draft_defines(self):
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        settings = dict(
            line.split("=", 1)
            for line in self.output.read_text().splitlines()
            if line and not line.startswith("//")
        )
        expected = {
            "FLUTTER_ROOT": str(self.flutter.resolve()),
            "FLUTTER_APPLICATION_PATH": str(self.project.resolve()),
            "FLUTTER_FRAMEWORK_SWIFT_PACKAGE_PATH": str(self.framework.resolve()),
            "FLUTTER_TARGET": str(self.project.resolve() / "lib/main.dart"),
            "FLUTTER_BUILD_NAME": "2.3.4",
            "FLUTTER_BUILD_NUMBER": "17",
            "PACKAGE_CONFIG": str(self.packages.resolve()),
            "FLAVOR": "draft",
        }
        for key, value in expected.items():
            with self.subTest(setting=key):
                self.assertEqual(settings[key], value)
        defines = {
            base64.b64decode(value, validate=True).decode("utf-8")
            for value in settings["DART_DEFINES"].split(",")
        }
        self.assertEqual(
            defines,
            {
                "SELAH_DRAFT_LOCAL_ONLY=true",
                "FLUTTER_APP_FLAVOR=draft",
                "FLUTTER_VERSION=3.44.2",
                "FLUTTER_CHANNEL=stable",
                "FLUTTER_GIT_URL=https://example.invalid/flutter.git",
                "FLUTTER_FRAMEWORK_REVISION=0123456789",
                "FLUTTER_ENGINE_REVISION=fedcba9876",
                "FLUTTER_DART_VERSION=3.12.2",
            },
        )

    def test_missing_build_number_defaults_to_one(self):
        self.pubspec.write_text("name: fixture\nversion: 2.3.4\n")
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("\nFLUTTER_BUILD_NUMBER=1\n", self.output.read_text())

    def test_resolves_symlinked_project_and_sdk_paths(self):
        root = Path(self.temporary.name)
        project_link = root / "project alias"
        flutter_link = root / "flutter alias"
        project_link.symlink_to(self.project, target_is_directory=True)
        flutter_link.symlink_to(self.flutter, target_is_directory=True)
        result = self.run_cli([str(project_link), str(flutter_link)])
        self.assertEqual(result.returncode, 0, result.stderr)
        content = self.output.read_text()
        self.assertIn(f"\nFLUTTER_ROOT={self.flutter.resolve()}\n", content)
        self.assertIn(
            f"\nFLUTTER_APPLICATION_PATH={self.project.resolve()}\n", content
        )

    def test_replaces_stale_settings_but_preserves_identical_output(self):
        self.output.write_text("stale settings\n")
        first = self.run_cli()
        self.assertEqual(first.returncode, 0, first.stderr)
        content = self.output.read_bytes()
        # An old timestamp makes an accidental rewrite visible without sleeping.
        os.utime(self.output, ns=(1_000_000_000, 1_000_000_000))
        before = self.output.stat().st_mtime_ns
        second = self.run_cli()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.output.read_bytes(), content)
        self.assertEqual(self.output.stat().st_mtime_ns, before)

    def test_rejects_each_changed_sdk_identity(self):
        for field, changed in {
            "flutterVersion": "3.44.3",
            "channel": "beta",
            "dartSdkVersion": "3.12.3",
        }.items():
            with self.subTest(field=field):
                original = self.manifest[field]
                self.manifest[field] = changed
                self.write_manifest()
                self.assert_refused("the pinned Flutter/Dart identity changed")
                self.manifest[field] = original

    def test_rejects_missing_empty_and_non_string_manifest_fields(self):
        absent = object()
        for field in tuple(self.manifest):
            original = self.manifest[field]
            for invalid in (absent, None, "", 123):
                with self.subTest(field=field, invalid=invalid):
                    if invalid is absent:
                        del self.manifest[field]
                    else:
                        self.manifest[field] = invalid
                    self.write_manifest()
                    self.assert_refused(f"missing {field}")
            self.manifest[field] = original

    def test_rejects_non_object_manifest(self):
        self.manifest_path.write_text("[]")
        self.assert_refused("invalid JSON object")

    def test_rejects_missing_required_inputs_without_overwriting_settings(self):
        required = (
            (self.manifest_path, "missing"),
            (self.pubspec, "missing"),
            (self.packages, "missing"),
            (self.framework, "prepared local FlutterFramework"),
        )
        for path, message in required:
            with self.subTest(path=path.relative_to(self.temporary.name)):
                parked = path.with_name(path.name + ".parked")
                path.rename(parked)
                try:
                    self.assert_refused(message)
                finally:
                    parked.rename(path)

    def test_rejects_pubspec_without_version(self):
        self.pubspec.write_text("name: fixture\n")
        self.assert_refused("pubspec.yaml has no valid version")

    def test_rejects_wrong_argument_count_without_creating_output(self):
        for arguments in ([], [str(self.project)], ["one", "two", "three"]):
            with self.subTest(arguments=arguments):
                result = self.run_cli(arguments)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("usage: generate_xcode_config.dart", result.stderr)
                self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
