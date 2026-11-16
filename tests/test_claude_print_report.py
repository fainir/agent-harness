import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest


SCRIPT = Path(__file__).resolve().parent.parent / "examples" / "claude-print-report.py"
REPORT = {
    "type": "assistant",
    "parent_tool_use_id": None,
    "message": {"content": [{"type": "text", "text": "One action remains."}]},
}
HANDOFF = {
    "type": "assistant",
    "parent_tool_use_id": None,
    "message": {"content": [{"type": "text", "text": "Saved the handoff."}]},
}
RESULT = {"type": "result", "result": "Saved the handoff.", "is_error": False}


def run(capture, *arguments):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), *arguments], input=capture,
                          encoding="utf-8", capture_output=True, timeout=10)


class PrintReportTest(unittest.TestCase):
    def test_keeps_earlier_report_and_followup_in_array_and_stream(self):
        mixed = [
            {"type": "system", "subtype": "init"},
            REPORT,
            {**REPORT, "parent_tool_use_id": "toolu_nested"},
            {"type": "stream_event"},
            HANDOFF,
            RESULT,
        ]
        for capture in (json.dumps(mixed, indent=2), "\n".join(map(json.dumps, mixed))):
            with self.subTest(capture=capture):
                completed = run(capture)
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual([json.loads(line) for line in completed.stdout.splitlines()], [
                    {"type": "assistant", "text": "One action remains."},
                    {"type": "assistant", "text": "Saved the handoff."},
                    RESULT,
                ])

    def test_preserves_a_standalone_error_result(self):
        failed = {**RESULT, "result": "Run ended early.", "is_error": True}
        completed = run(json.dumps(failed))
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(json.loads(completed.stdout), failed)

    def test_reads_a_named_capture_with_a_utf8_bom(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "print capture.json"
            path.write_text(json.dumps([REPORT, RESULT]), encoding="utf-8-sig")
            completed = run("", str(path))
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual([json.loads(line) for line in completed.stdout.splitlines()], [
            {"type": "assistant", "text": "One action remains."}, RESULT,
        ])

    def test_corrupt_capture_does_not_output_a_partial_report(self):
        completed = run(json.dumps(REPORT) + '\n{"type":')
        self.assertNotEqual(completed.returncode, 0)
        self.assertEqual(completed.stdout, "")
        self.assertIn("Invalid Claude Code capture", completed.stderr)


if __name__ == "__main__":
    unittest.main()
