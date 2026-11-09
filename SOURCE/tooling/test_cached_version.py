"""Exercise the cached Flutter version gate with retained, isolated fixtures."""

import argparse
import json
from pathlib import Path
import subprocess


GATE = Path(__file__).with_name("cached_version.dart").resolve()
PINNED_MANIFEST = {
    "frameworkVersion": "3.44.2",
    "channel": "stable",
    "repositoryUrl": "https://github.com/flutter/flutter.git",
    "frameworkRevision": "c9a6c484230f8b5e408ec57be1ef71dee1e77020",
    "frameworkCommitDate": "2026-01-01",
    "engineRevision": "77e2e94772b6eb43759e34ed1ad7da4674e19cab",
    "dartSdkVersion": "3.12.2",
    "devToolsVersion": "0.0.0",
    "flutterVersion": "3.44.2",
}


def write_manifest(root, manifest):
    cache = root / "bin" / "cache"
    cache.mkdir(parents=True)
    (cache / "flutter.version.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )


def check_refusal(dart, root, expected):
    result = subprocess.run(
        [str(dart), "--disable-dart-dev", str(GATE), str(root)],
        cwd=root,
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )
    if result.returncode != 1 or result.stdout or expected not in result.stderr:
        raise AssertionError(
            f"{root.name}: expected exit 1 and {expected!r} on stderr. "
            f"Got exit {result.returncode}, stdout {result.stdout!r}, "
            f"stderr {result.stderr!r}."
        )
    print(f"PASS: {root.name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dart", type=Path, help="path to the pinned Dart VM")
    parser.add_argument("scratch", type=Path, help="new directory for retained fixtures")
    args = parser.parse_args()

    dart = args.dart.absolute()
    scratch = args.scratch.absolute()
    scratch.mkdir()

    missing_manifest = scratch / "missing-manifest"
    missing_manifest.mkdir()
    check_refusal(dart, missing_manifest, "Pinned Flutter version manifest is missing.")

    drifted_engine = scratch / "drifted-engine"
    write_manifest(drifted_engine, {**PINNED_MANIFEST, "engineRevision": "different"})
    check_refusal(dart, drifted_engine, "Selah delivery is pinned to cached Flutter 3.44.2.")

    missing_tool = scratch / "missing-tool"
    write_manifest(missing_tool, PINNED_MANIFEST)
    missing_dart = missing_tool / "bin" / "cache" / "dart-sdk" / "bin" / "dart"
    check_refusal(dart, missing_tool, f"Required cached tool is missing. {missing_dart}")


if __name__ == "__main__":
    main()
