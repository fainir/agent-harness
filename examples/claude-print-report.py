"""Read saved Claude Code print output and emit report events as JSONL."""

import argparse
import json
from pathlib import Path
import re
import sys


WHITESPACE = re.compile(r"[ \t\r\n]*")


def events(capture):
    decoder = json.JSONDecoder()
    position = 0
    while True:
        position = WHITESPACE.match(capture, position).end()
        if position == len(capture):
            return
        value, position = decoder.raw_decode(capture, position)
        if isinstance(value, list):
            yield from value
        else:
            yield value


def report_events(capture):
    for event in events(capture):
        if not isinstance(event, dict):
            raise ValueError("Expected a JSON event object")
        if event.get("type") == "result":
            yield event
        if event.get("type") != "assistant" or event.get("parent_tool_use_id", False) is not None:
            continue
        text = [block["text"] for block in event.get("message", {}).get("content", [])
                if block.get("type") == "text" and isinstance(block.get("text"), str)]
        if text:
            yield {"type": "assistant", "text": "\n".join(text)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path, nargs="?", help="UTF-8 capture file (defaults to stdin)")
    args = parser.parse_args()
    try:
        capture = args.capture.read_bytes() if args.capture else sys.stdin.buffer.read()
        output = list(report_events(capture.decode("utf-8-sig")))
    except (OSError, ValueError) as error:
        sys.exit(f"Invalid Claude Code capture: {error}")
    for record in output:
        print(json.dumps(record))
