#!/usr/bin/env python3
"""Validate sprint-status.yaml for duplicate keys and basic structure."""

import sys

def validate(filepath):
    with open(filepath) as f:
        content = f.read()

    lines = [l.strip() for l in content.split('\n')
             if l.strip() and not l.strip().startswith('#')]

    keys = [l.split(':')[0].strip() for l in lines
            if ':' in l and not l.startswith('-')]

    dupes = set(k for k in keys if keys.count(k) > 1)

    if dupes:
        print(f"FAIL: Duplicate keys: {dupes}")
        return 1

    print(f"OK: {len(keys)} keys, no duplicates")
    return 0

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "docs/implementation-artifacts/sprint-status.yaml"
    sys.exit(validate(path))
