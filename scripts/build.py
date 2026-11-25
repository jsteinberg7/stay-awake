#!/usr/bin/env python3
"""Build a universal native macOS app using the Swift compiler."""
import argparse
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "dist" / "Stay Awake.app"


def timer_plist():
    return plistlib.dumps({
        "Label": "io.github.stay-awake.timer",
        "ProgramArguments": ["/bin/sh", "-c", (ROOT / "src/timer.sh").read_text(),
                             "stay-awake-timer", "__DEADLINE__", "__BOOT__"],
        "RunAtLoad": True,
        "StartInterval": 5,
    }).decode()


def controller_source():
    # Protect the fixed shell script against heredoc expansion, then insert
    # precisely the two variables we intend the controller to expand.
    xml = timer_plist().replace("\\", "\\\\").replace("$", "\\$").replace("`", "\\`")
    xml = xml.replace("__DEADLINE__", "$deadline").replace("__BOOT__", "$boot")
    return (ROOT / "src/controller.sh").read_text().replace("@@TIMER_PLIST@@", xml)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--test-ui", action="store_true", help="Exercise native duration controls without changing power settings")
    args = parser.parse_args()
    APP.parent.mkdir(exist_ok=True)
    if APP.exists():
        shutil.rmtree(APP)
    resources = APP / "Contents/Resources"
    resources.mkdir(parents=True)
    binaries = APP / "Contents/MacOS"
    binaries.mkdir()
    slices = []
    for architecture in ("arm64", "x86_64"):
        binary = APP.parent / ("StayAwake-" + architecture)
        subprocess.run(["xcrun", "swiftc", "-O", "-target", architecture + "-apple-macos12.0",
                        "-framework", "AppKit", str(ROOT / "src/main.swift"), "-o", str(binary)], check=True)
        slices.append(str(binary))
    subprocess.run(["xcrun", "lipo", "-create", *slices, "-output", str(binaries / "StayAwake")], check=True)
    (resources / "controller.sh").write_text(controller_source())
    info_path = APP / "Contents/Info.plist"
    info = dict(CFBundleIdentifier="io.github.stay-awake.app",
                CFBundleName="Stay Awake", CFBundleDisplayName="Stay Awake",
                CFBundleExecutable="StayAwake", CFBundlePackageType="APPL",
                CFBundleShortVersionString="1.1.0", CFBundleVersion="4",
                NSPrincipalClass="NSApplication", NSHighResolutionCapable=True,
                LSApplicationCategoryType="public.app-category.utilities",
                LSMinimumSystemVersion="12.0",
                NSHumanReadableCopyright="Copyright 2026 Stay Awake contributors. MIT license.")
    info_path.write_bytes(plistlib.dumps(info))
    subprocess.run(["codesign", "--force", "--sign", "-", str(APP)], check=True)
    # Spotlight indexes these attributes; ditto preserves them in release ZIPs.
    metadata = {
        "kMDItemKeywords": ["caffeinate", "stay awake", "keep awake"],
        "kMDItemFinderComment": "caffeinate: keep your Mac awake with the lid closed for a chosen duration.",
    }
    for key, value in metadata.items():
        encoded = plistlib.dumps(value, fmt=plistlib.FMT_BINARY).hex()
        subprocess.run(["xattr", "-wx", "com.apple.metadata:" + key, encoded, str(APP)], check=True)
    # Archive a parent directory so ditto includes the app root's attributes.
    # Archiving the app itself with --keepParent silently drops those attributes.
    archive = APP.parent / "Stay-Awake.zip"
    with tempfile.TemporaryDirectory() as stage, tempfile.TemporaryDirectory() as extracted:
        subprocess.run(["ditto", "--rsrc", "--extattr", str(APP), stage + "/Stay Awake.app"], check=True)
        subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--rsrc", "--extattr", stage, str(archive)], check=True)
        subprocess.run(["ditto", "-x", "-k", str(archive), extracted], check=True)
        saved = subprocess.check_output(["xattr", "-px", "com.apple.metadata:kMDItemKeywords", extracted + "/Stay Awake.app"])
        if "caffeinate" not in plistlib.loads(bytes.fromhex(saved.decode())):
            raise RuntimeError("Release archive lost its Spotlight search metadata")
    print(APP)
    if args.test_ui:
        test_binary = APP.parent / "DurationControlsSmoke"
        subprocess.run(["xcrun", "swiftc", "-D", "UI_SMOKE_TEST", "-framework", "AppKit",
                        str(ROOT / "src/main.swift"), str(ROOT / "tests/DurationControlsSmoke.swift"),
                        "-o", str(test_binary)], check=True)
        subprocess.run([str(test_binary)], check=True)


if __name__ == "__main__":
    main()
