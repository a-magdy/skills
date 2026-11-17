#!/usr/bin/env python3
"""Validate the read-only JSON inventories exposed by both supported CLIs."""

import json
import sys
from pathlib import Path


def source_matches(entry: dict, expected: str) -> bool:
    source = entry.get("source")
    if not isinstance(source, str):
        raise ValueError("marketplace source is unavailable")
    if source == "directory":
        actual = entry.get("path")
    elif source == "github":
        actual = entry.get("repo")
    elif source.startswith(("GitHub: ", "Local: ")):
        actual = source.split(": ", 1)[1]
    else:
        raise ValueError("unsupported marketplace source")
    if not isinstance(actual, str):
        raise ValueError("marketplace locator is unavailable")
    if expected.startswith("/"):
        return actual.startswith("/") and Path(actual).resolve() == Path(expected).resolve()
    return actual.removeprefix("https://github.com/").removesuffix(".git") == expected


def main() -> int:
    mode, cli, name, expected = sys.argv[1:]
    try:
        entries = json.load(sys.stdin)
        if not isinstance(entries, list) or not all(isinstance(e, dict) for e in entries):
            raise ValueError("expected a JSON array of objects")
        if mode in ("registered", "marketplace"):
            if any(not isinstance(e.get("name"), str) for e in entries):
                raise ValueError("marketplace names are unavailable")
            matches = [e for e in entries if e["name"] == name]
            if not matches:
                if mode != "registered":
                    print(f"MISSING {cli} marketplace {name}")
                return 1
            if len(matches) != 1:
                raise ValueError("ambiguous marketplace entries")
            if mode == "marketplace" and not source_matches(matches[0], expected):
                print(f"WRONG {cli} marketplace {name} source (switch explicitly)")
                return 1
        elif mode == "plugin":
            if cli == "claude":
                if any(not isinstance(e.get("id"), str) for e in entries):
                    raise ValueError("plugin IDs are unavailable")
                matches = [e for e in entries if e["id"] == name]
            else:
                if any(not isinstance(e.get("name"), str) or
                       not isinstance(e.get("marketplace"), str) for e in entries):
                    raise ValueError("plugin identities are unavailable")
                matches = [e for e in entries if f'{e["name"]}@{e["marketplace"]}' == name]
            if not matches:
                print(f"MISSING {cli} plugin {name}")
                return 1
            for entry in matches:
                if type(entry.get("enabled")) is not bool:
                    raise ValueError("plugin enabled state is unavailable")
                if not entry["enabled"] or entry.get("projectEnabled") is False:
                    print(f"DISABLED {cli} plugin {name}")
                    return 1
                if entry.get("errors"):
                    print(f"ERROR {cli} plugin {name} reports load errors")
                    return 1
        else:
            raise ValueError("unsupported inventory operation")
    except (ValueError, OSError) as exc:
        # Do not echo raw CLI JSON: it can contain machine paths or private URLs.
        detail = "invalid JSON" if isinstance(exc, json.JSONDecodeError) else str(exc)
        print(f"UNKNOWN {cli} {name}: {detail}", file=sys.stderr)
        return 2
    if mode != "registered":
        print(f"ok {cli} {mode} {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
