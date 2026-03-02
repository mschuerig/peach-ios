#!/usr/bin/env python3
"""
bin/add-localization.py — Add German localization entries to Localizable.xcstrings.

Usage:
    # Single entry
    bin/add-localization.py "Settings" "Einstellungen"
    bin/add-localization.py "Target interval: %@" "Zielintervall: %@"

    # Batch from JSON file (object with "key": "German translation")
    bin/add-localization.py --batch translations.json

    # Batch from CSV (key,translation per line, no header)
    bin/add-localization.py --batch translations.csv

    # List existing keys (useful for checking what's already there)
    bin/add-localization.py --list
    bin/add-localization.py --list | grep -i interval

    # Show entries missing a German translation
    bin/add-localization.py --missing

    # Dry run (show what would be added/changed without writing)
    bin/add-localization.py --dry-run "Settings" "Einstellungen"
    bin/add-localization.py --dry-run --batch translations.json

Options:
    --xcstrings PATH    Path to .xcstrings file (default: auto-detect in project)
    --batch FILE        Read translations from JSON or CSV file
    --list              List all existing localization keys
    --missing           Show keys without a German translation
    --dry-run           Show changes without writing
    --sort              Sort keys alphabetically when writing (default: preserve order)
"""

import argparse
import csv
import json
import os
import sys
from pathlib import Path


def find_xcstrings():
    """Auto-detect the Localizable.xcstrings file."""
    # Try common locations relative to the script or cwd
    candidates = [
        Path("Peach/Resources/Localizable.xcstrings"),
        Path("Resources/Localizable.xcstrings"),
        Path("Localizable.xcstrings"),
    ]

    # Also try relative to the script location
    script_dir = Path(__file__).resolve().parent.parent
    for c in list(candidates):
        candidates.append(script_dir / c)

    for c in candidates:
        if c.exists():
            return c

    # Search upward from cwd
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        found = list(parent.rglob("Localizable.xcstrings"))
        if found:
            return found[0]

    return None


def load_xcstrings(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def save_xcstrings(path, data, sort_keys=False):
    strings = data.get('strings', {})
    if sort_keys:
        data['strings'] = dict(sorted(strings.items()))

    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')


def make_entry(german_value):
    """Create a localization entry for a German translation."""
    return {
        "localizations": {
            "de": {
                "stringUnit": {
                    "state": "translated",
                    "value": german_value
                }
            }
        }
    }


def add_translations(data, translations, dry_run=False):
    """Add translations, return (added, updated, skipped) counts."""
    strings = data.setdefault('strings', {})
    added = 0
    updated = 0
    skipped = 0

    for key, german in translations.items():
        if key in strings:
            # Check if German translation already exists and matches
            existing_de = (strings[key]
                          .get('localizations', {})
                          .get('de', {})
                          .get('stringUnit', {})
                          .get('value'))

            if existing_de == german:
                skipped += 1
                if dry_run:
                    print(f"  skip (identical): {key!r}")
                continue

            # Update existing entry, preserving other localizations
            if 'localizations' not in strings[key]:
                strings[key]['localizations'] = {}
            strings[key]['localizations']['de'] = {
                'stringUnit': {
                    'state': 'translated',
                    'value': german
                }
            }
            updated += 1
            if dry_run:
                old = existing_de or "(none)"
                print(f"  update: {key!r}: {old!r} → {german!r}")
        else:
            strings[key] = make_entry(german)
            added += 1
            if dry_run:
                print(f"  add: {key!r} → {german!r}")

    return added, updated, skipped


def load_batch_file(path):
    """Load translations from a JSON or CSV file."""
    p = Path(path)

    if p.suffix == '.json':
        with open(p, 'r', encoding='utf-8') as f:
            data = json.load(f)
        if not isinstance(data, dict):
            print(f"Error: JSON file must be an object with {{\"key\": \"translation\"}}",
                  file=sys.stderr)
            sys.exit(1)
        return data

    # Assume CSV (also handles .tsv, .txt)
    translations = {}
    with open(p, 'r', encoding='utf-8') as f:
        # Auto-detect delimiter
        sample = f.read(4096)
        f.seek(0)
        if '\t' in sample:
            delimiter = '\t'
        else:
            delimiter = ','

        reader = csv.reader(f, delimiter=delimiter)
        for row in reader:
            if len(row) >= 2:
                key = row[0].strip()
                value = row[1].strip()
                if key and value:
                    translations[key] = value

    return translations


def list_keys(data):
    strings = data.get('strings', {})
    for key in sorted(strings.keys()):
        de = (strings[key]
              .get('localizations', {})
              .get('de', {})
              .get('stringUnit', {})
              .get('value', ''))
        if de:
            print(f"{key}  →  {de}")
        else:
            print(f"{key}  →  (no German translation)")


def show_missing(data):
    strings = data.get('strings', {})
    count = 0
    for key in sorted(strings.keys()):
        de = (strings[key]
              .get('localizations', {})
              .get('de', {})
              .get('stringUnit', {})
              .get('value'))
        if not de:
            print(key)
            count += 1
    print(f"\n{count} keys missing German translation", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description='Add German localizations to Localizable.xcstrings')
    parser.add_argument('key', nargs='?', help='Localization key (English string)')
    parser.add_argument('german', nargs='?', help='German translation')
    parser.add_argument('--xcstrings', help='Path to .xcstrings file')
    parser.add_argument('--batch', metavar='FILE',
                        help='Read translations from JSON or CSV file')
    parser.add_argument('--list', action='store_true',
                        help='List all existing keys and their German translations')
    parser.add_argument('--missing', action='store_true',
                        help='Show keys without German translations')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would change without writing')
    parser.add_argument('--sort', action='store_true',
                        help='Sort keys alphabetically when writing')

    args = parser.parse_args()

    # Find the xcstrings file
    if args.xcstrings:
        xcstrings_path = Path(args.xcstrings)
    else:
        xcstrings_path = find_xcstrings()

    if not xcstrings_path or not xcstrings_path.exists():
        print("Error: Could not find Localizable.xcstrings", file=sys.stderr)
        print("Specify path with --xcstrings", file=sys.stderr)
        sys.exit(1)

    data = load_xcstrings(xcstrings_path)

    # --- List mode ---
    if args.list:
        list_keys(data)
        return

    # --- Missing mode ---
    if args.missing:
        show_missing(data)
        return

    # --- Collect translations ---
    translations = {}

    if args.batch:
        translations = load_batch_file(args.batch)
    elif args.key and args.german:
        translations = {args.key: args.german}
    else:
        parser.print_help()
        sys.exit(1)

    if not translations:
        print("No translations to add.", file=sys.stderr)
        sys.exit(1)

    # --- Apply ---
    if args.dry_run:
        print(f"Dry run against {xcstrings_path}:\n")

    added, updated, skipped = add_translations(data, translations, dry_run=args.dry_run)

    if not args.dry_run:
        save_xcstrings(xcstrings_path, data, sort_keys=args.sort)

    action = "Would add" if args.dry_run else "Added"
    print(f"\n{action} {added}, updated {updated}, skipped {skipped} "
          f"(of {len(translations)} entries) in {xcstrings_path.name}")


if __name__ == '__main__':
    main()
