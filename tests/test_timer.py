"""Exercise the real shell scripts with isolated power and launchd commands."""
import importlib.util
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("build", ROOT / "scripts/build.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class PowerSessionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.daemons = self.root / "LaunchDaemons"
        self.daemons.mkdir()
        self.plist = self.daemons / "io.github.stay-awake.timer.plist"
        self.log = self.root / "calls"
        self.state = self.root / "state"
        self.state.write_text("0")
        self.env = dict(os.environ, CALLS=str(self.log), STATE=str(self.state),
                        NOW="1000", BOOT="ABC-123")
        scripts = {
            "/usr/bin/id": 'echo 0',
            "/usr/sbin/sysctl": 'echo "$BOOT"',
            "/bin/date": 'echo "$NOW"',
            "/usr/sbin/chown": 'exit 0',
            "/usr/bin/pmset": '''echo "pmset $*" >> "$CALLS"
if [ "$1" = -g ]; then printf ' SleepDisabled %s\\n' "$(cat "$STATE")"; exit; fi
if [ "${FAIL_RESET:-}" = 1 ] && [ "$3" = 0 ]; then exit 1; fi
echo "$3" > "$STATE"''',
            "/bin/launchctl": '''echo "launchctl $*" >> "$CALLS"
if [ "${FAIL_BOOTSTRAP:-}" = 1 ] && [ "$1" = bootstrap ]; then exit 1; fi''',
        }
        self.replacements = {"/Library/LaunchDaemons": str(self.daemons)}
        for index, (original, script) in enumerate(scripts.items()):
            path = self.root / f"command{index}"
            path.write_text("#!/bin/sh\n" + script + "\n")
            path.chmod(0o755)
            self.replacements[original] = str(path)

    def run_script(self, source, *args):
        for original, replacement in self.replacements.items():
            source = source.replace(original, replacement)
        script = self.root / "run.sh"
        script.write_text(source)
        return subprocess.run(["/bin/sh", str(script), *args], env=self.env,
                              capture_output=True, text=True)

    def controller(self, *args):
        return self.run_script(build.controller_source(), *args)

    def timer(self, deadline="1100", boot="ABC-123"):
        return self.run_script((ROOT / "src/timer.sh").read_text(), deadline, boot)

    def test_start_installs_exact_timer_and_enables_sleep_override(self):
        result = self.controller("start", "7200")
        self.assertEqual(result.returncode, 0, result.stderr)
        plist = plistlib.loads(self.plist.read_bytes())
        self.assertEqual(plist["ProgramArguments"][-2:], ["8200", "ABC-123"])
        expected_script = (ROOT / "src/timer.sh").read_text()
        for original, replacement in self.replacements.items():
            expected_script = expected_script.replace(original, replacement)
        self.assertEqual(plist["ProgramArguments"][2], expected_script)
        self.assertEqual(self.state.read_text().strip(), "1")

    def test_invalid_durations_do_not_change_power(self):
        for value in ["", "0", "59", "604801", "999999999999999999", "-1", "1.5", "1; touch nope"]:
            with self.subTest(value=value):
                self.assertNotEqual(self.controller("start", value).returncode, 0)
                self.assertEqual(self.state.read_text(), "0")
                self.assertFalse(self.plist.exists())

    def test_failed_registration_restores_sleep(self):
        self.env["FAIL_BOOTSTRAP"] = "1"
        self.assertNotEqual(self.controller("start", "60").returncode, 0)
        self.assertEqual(self.state.read_text().strip(), "0")
        self.assertFalse(self.plist.exists())

    def test_unowned_override_is_not_replaced(self):
        self.state.write_text("1")
        self.assertNotEqual(self.controller("start", "60").returncode, 0)
        self.assertEqual(self.state.read_text(), "1")
        self.assertFalse(self.plist.exists())

    def test_new_session_replaces_deadline(self):
        self.assertEqual(self.controller("start", "60").returncode, 0)
        self.assertEqual(self.controller("start", "7200").returncode, 0)
        self.assertEqual(plistlib.loads(self.plist.read_bytes())["ProgramArguments"][-2], "8200")

    def test_timer_does_nothing_before_deadline(self):
        self.plist.write_text("placeholder")
        self.state.write_text("1")
        self.assertEqual(self.timer().returncode, 0)
        self.assertTrue(self.plist.exists())
        self.assertEqual(self.state.read_text(), "1")

    def test_expiry_restores_sleep_and_removes_job(self):
        self.plist.write_text("placeholder")
        self.state.write_text("1")
        self.assertEqual(self.timer(deadline="1000").returncode, 0)
        self.assertEqual(self.state.read_text().strip(), "0")
        self.assertFalse(self.plist.exists())
        self.assertIn("bootout system/io.github.stay-awake.timer", self.log.read_text())

    def test_restart_ends_session_early(self):
        self.plist.write_text("placeholder")
        self.state.write_text("1")
        self.assertEqual(self.timer(boot="PREVIOUS-BOOT").returncode, 0)
        self.assertEqual(self.state.read_text().strip(), "0")
        self.assertFalse(self.plist.exists())

    def test_failed_restoration_preserves_job_for_retry(self):
        self.plist.write_text("placeholder")
        self.env["FAIL_RESET"] = "1"
        self.assertNotEqual(self.timer(deadline="900").returncode, 0)
        self.assertTrue(self.plist.exists())

    def test_stop_restores_sleep_and_removes_job(self):
        self.assertEqual(self.controller("start", "60").returncode, 0)
        self.assertEqual(self.controller("stop").returncode, 0)
        self.assertEqual(self.state.read_text().strip(), "0")
        self.assertFalse(self.plist.exists())


if __name__ == "__main__":
    unittest.main()
