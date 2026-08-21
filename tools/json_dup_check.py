#!/usr/bin/env python3
"""json_dup_check.py — validate JSON and report duplicate object keys.

Standard JSON parsers (including jq and python's json) silently keep the last
value for duplicate keys. Ventoy reads ventoy.json positionally per plugin, so a
duplicate top-level key (e.g. two "theme" objects) can silently discard user
configuration. This tool fails loudly instead.

Usage:
    json_dup_check.py FILE [FILE...]

Exit codes: 0 = all files valid, no duplicates
            1 = invalid JSON syntax
            2 = valid JSON but duplicate keys found
"""
import json
import sys


class DuplicateKeyError(ValueError):
    pass


def _hook(pairs):
    seen = set()
    obj = {}
    for key, value in pairs:
        if key in seen:
            raise DuplicateKeyError(f"duplicate object key: {key!r}")
        seen.add(key)
        obj[key] = value
    return obj


def check(path: str) -> int:
    try:
        with open(path, "r", encoding="utf-8-sig") as handle:  # tolerate a UTF-8 BOM
            json.load(handle, object_pairs_hook=_hook)
    except DuplicateKeyError as exc:
        print(f"{path}: DUPLICATE KEY: {exc}")
        return 2
    except (OSError, ValueError) as exc:
        print(f"{path}: INVALID JSON: {exc}")
        return 1
    print(f"{path}: OK (valid JSON, no duplicate keys)")
    return 0


def main(argv) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 1
    worst = 0
    for path in argv[1:]:
        worst = max(worst, check(path))
    return worst


if __name__ == "__main__":
    sys.exit(main(sys.argv))
