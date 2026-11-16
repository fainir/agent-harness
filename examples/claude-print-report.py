"""Read saved Claude Code print output from stdin and emit report events as JSONL."""

import json
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
    try:
        output = list(report_events(sys.stdin.buffer.read().decode("utf-8-sig")))
    except ValueError as error:
        sys.exit(f"Invalid Claude Code capture: {error}")
    for record in output:
        print(json.dumps(record))
