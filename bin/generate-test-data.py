#!/usr/bin/env python3
"""Generate a CSV file with backdated training data for testing.

Creates training records at multiple time ranges so all bucket types appear:
  - 2-3 months ago  -> month buckets (tap to expand into weeks)
  - 2-3 weeks ago   -> week buckets  (tap to expand into days)
  - 2-3 days ago    -> day buckets   (tap to expand into sessions)
  - Today           -> session buckets (finest level, not expandable)

Supports 4 training modes:
  --comparison-unison     pitchComparison with P1 interval
  --comparison-interval   pitchComparison with random non-unison intervals
  --matching-unison       pitchMatching with P1 interval
  --matching-interval     pitchMatching with random non-unison intervals

Without any mode flags, generates records distributed across all 4 modes.

Usage:
    python3 bin/generate-test-data.py                          # 100 records, all modes
    python3 bin/generate-test-data.py --comparison-unison      # 100 comparison-unison
    python3 bin/generate-test-data.py --count 50 output.csv    # 50 records to custom path

Then import the CSV in the app via Settings > Import Training Data (merge mode).
"""

import argparse
import csv
import random
from datetime import datetime, timedelta, timezone

METADATA_LINE = "# peach-export-format:1"

HEADER = [
    "trainingType", "timestamp",
    "referenceNote", "referenceNoteName",
    "targetNote", "targetNoteName",
    "interval", "tuningSystem",
    "centOffset", "isCorrect",
    "initialCentOffset", "userCentError",
]

NOTE_NAMES = [
    "C", "C#", "D", "D#", "E", "F",
    "F#", "G", "G#", "A", "A#", "B",
]

INTERVALS = {
    0: "P1", 1: "m2", 2: "M2", 3: "m3", 4: "M3", 5: "P4",
    6: "d5", 7: "P5", 8: "m6", 9: "M6", 10: "m7", 11: "M7", 12: "P8",
}

NON_UNISON_SEMITONES = [s for s in INTERVALS if s != 0]


def midi_name(note: int) -> str:
    octave = note // 12 - 1
    return f"{NOTE_NAMES[note % 12]}{octave}"


def iso_timestamp(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def random_ref_note() -> int:
    return random.randint(48, 84)


def random_interval():
    semitones = random.choice(NON_UNISON_SEMITONES)
    return INTERVALS[semitones], semitones


def random_cent_offset() -> float:
    magnitude = round(random.uniform(1, 25), 1)
    return magnitude * random.choice([-1, 1])


def random_initial_cent_offset() -> float:
    return round(random.uniform(-20, 20), 1)


def random_user_cent_error() -> float:
    return round(random.uniform(1, 15), 1)


def pitch_comparison_row(timestamp: datetime, cent_offset: float,
                         interval_abbrev: str, ref_note: int,
                         target_note: int) -> list:
    return [
        "pitchComparison",
        iso_timestamp(timestamp),
        str(ref_note), midi_name(ref_note),
        str(target_note), midi_name(target_note),
        interval_abbrev,
        "equalTemperament",
        f"{cent_offset:.1f}",
        random.choice(["true", "false"]),
        "",  # initialCentOffset (pitchComparison doesn't use)
        "",  # userCentError (pitchComparison doesn't use)
    ]


def pitch_matching_row(timestamp: datetime, initial_cent_offset: float,
                       user_cent_error: float, interval_abbrev: str,
                       ref_note: int, target_note: int) -> list:
    return [
        "pitchMatching",
        iso_timestamp(timestamp),
        str(ref_note), midi_name(ref_note),
        str(target_note), midi_name(target_note),
        interval_abbrev,
        "equalTemperament",
        "",  # centOffset (pitchMatching doesn't use)
        "",  # isCorrect (pitchMatching doesn't use)
        f"{initial_cent_offset:.1f}",
        f"{user_cent_error:.1f}",
    ]


def make_row(mode: str, timestamp: datetime) -> list:
    ref = random_ref_note()

    if mode == "comparison-unison":
        return pitch_comparison_row(timestamp, random_cent_offset(), "P1", ref, ref)

    elif mode == "comparison-interval":
        abbrev, semitones = random_interval()
        target = ref + semitones
        if target > 127:
            target = ref - semitones
        return pitch_comparison_row(timestamp, random_cent_offset(), abbrev, ref, target)

    elif mode == "matching-unison":
        return pitch_matching_row(timestamp, random_initial_cent_offset(),
                                  random_user_cent_error(), "P1", ref, ref)

    elif mode == "matching-interval":
        abbrev, semitones = random_interval()
        target = ref + semitones
        if target > 127:
            target = ref - semitones
        return pitch_matching_row(timestamp, random_initial_cent_offset(),
                                  random_user_cent_error(), abbrev, ref, target)

    else:
        raise ValueError(f"Unknown mode: {mode}")


def generate_timestamps(count: int) -> list[datetime]:
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    timestamps = []

    # Distribute into 4 time buckets proportionally
    month_share = int(count * 0.40)
    week_share = int(count * 0.30)
    day_share = int(count * 0.20)
    today_share = count - month_share - week_share - day_share

    for _ in range(month_share):
        offset = random.uniform(60, 180)
        timestamps.append(now - timedelta(days=offset))

    for _ in range(week_share):
        offset = random.uniform(10, 20)
        timestamps.append(now - timedelta(days=offset))

    for _ in range(day_share):
        days_ago = random.choice([2, 3])
        day_base = today_start - timedelta(days=days_ago)
        seconds_in_day = random.uniform(0, 86400)
        timestamps.append(day_base + timedelta(seconds=seconds_in_day))

    for _ in range(today_share):
        seconds = random.uniform(0, (now - today_start).total_seconds())
        timestamps.append(today_start + timedelta(seconds=seconds))

    timestamps.sort()
    return timestamps


def generate_records(modes: list[str], count: int) -> list:
    timestamps = generate_timestamps(count)
    rows = []

    for i, ts in enumerate(timestamps):
        mode = modes[i % len(modes)]
        rows.append(make_row(mode, ts))

    return rows


def main():
    parser = argparse.ArgumentParser(
        description="Generate CSV test data for Peach training modes.")
    parser.add_argument("output", nargs="?", default="test-data.csv",
                        help="Output CSV file path (default: test-data.csv)")
    parser.add_argument("--count", type=int, default=100,
                        help="Number of records to generate (default: 100)")
    parser.add_argument("--comparison-unison", action="store_true",
                        help="Generate pitch comparison unison records")
    parser.add_argument("--comparison-interval", action="store_true",
                        help="Generate pitch comparison interval records")
    parser.add_argument("--matching-unison", action="store_true",
                        help="Generate pitch matching unison records")
    parser.add_argument("--matching-interval", action="store_true",
                        help="Generate pitch matching interval records")
    args = parser.parse_args()

    modes = []
    if args.comparison_unison:
        modes.append("comparison-unison")
    if args.comparison_interval:
        modes.append("comparison-interval")
    if args.matching_unison:
        modes.append("matching-unison")
    if args.matching_interval:
        modes.append("matching-interval")

    if not modes:
        modes = ["comparison-unison", "comparison-interval",
                 "matching-unison", "matching-interval"]

    rows = generate_records(modes, args.count)

    with open(args.output, "w", newline="") as f:
        f.write(METADATA_LINE + "\n")
        writer = csv.writer(f)
        writer.writerow(HEADER)
        writer.writerows(rows)

    # Count per mode
    mode_counts = {}
    for row in rows:
        training_type = row[0]
        interval = row[6]
        if training_type == "pitchComparison" and interval == "P1":
            key = "comparison-unison"
        elif training_type == "pitchComparison":
            key = "comparison-interval"
        elif training_type == "pitchMatching" and interval == "P1":
            key = "matching-unison"
        else:
            key = "matching-interval"
        mode_counts[key] = mode_counts.get(key, 0) + 1

    print(f"Written {len(rows)} records to {args.output}")
    for mode, cnt in sorted(mode_counts.items()):
        print(f"  {mode}: {cnt} records")
    print()
    print("Import via: Settings > Import Training Data > Merge")


if __name__ == "__main__":
    main()
