from pathlib import Path
import subprocess
import unittest

PARSER = Path(__file__).resolve().parent.parent / "src/duration.awk"


class DurationTests(unittest.TestCase):
    def parse(self, value):
        return subprocess.run(["/usr/bin/awk", "-f", str(PARSER)], input=value,
                              text=True, capture_output=True)

    def test_friendly_durations(self):
        cases = {"30m": 1800, "2h": 7200, "1h 30m": 5400, "1h30m": 5400,
                 "30 minutes": 1800, "1 hour 30 minutes": 5400,
                 "2 hrs": 7200, "90": 5400, " 30 MINS ": 1800,
                 "0.5h": 1800, ".5h": 1800, "1m": 60, "168h": 604800}
        for text, seconds in cases.items():
            with self.subTest(text=text):
                result = self.parse(text)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), str(seconds))

    def test_invalid_or_out_of_range_durations(self):
        for text in ["", " ", "0", "0.5m", "169h", "-1h", "forever", "1h30",
                     "1 2h", "1e3h", "30m; touch /tmp/no", "NaNh", "1h nonsense"]:
            with self.subTest(text=text):
                result = self.parse(text)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
