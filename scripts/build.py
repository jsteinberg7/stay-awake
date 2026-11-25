#!/usr/bin/env python3
"""Build a standalone AppleScript app using macOS's own compiler."""
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
    APP.parent.mkdir(exist_ok=True)
    if APP.exists():
        shutil.rmtree(APP)
    subprocess.run(["osacompile", "-o", str(APP), str(ROOT / "src/Stay Awake.applescript")], check=True)
    resources = APP / "Contents/Resources"
    (resources / "controller.sh").write_text(controller_source())
    shutil.copyfile(ROOT / "src/duration.awk", resources / "duration.awk")
    info_path = APP / "Contents/Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info.update(CFBundleIdentifier="io.github.stay-awake.app",
                CFBundleName="Stay Awake", CFBundleDisplayName="Stay Awake",
                CFBundleShortVersionString="1.0.2", CFBundleVersion="3",
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


if __name__ == "__main__":
    main()
