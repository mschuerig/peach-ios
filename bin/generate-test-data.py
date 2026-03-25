#!/usr/bin/env python3
"""Generate a CSV file with backdated training data for testing.

Creates training records at multiple time ranges so all bucket types appear:
  - 2-3 months ago  -> month buckets (tap to expand into weeks)
  - 2-3 weeks ago   -> week buckets  (tap to expand into days)
  - 2-3 days ago    -> day buckets   (tap to expand into sessions)
  - Today           -> session buckets (finest level, not expandable)

Supports 6 training disciplines:
  --discrimination-unison     pitchDiscrimination with P1 interval
  --discrimination-interval   pitchDiscrimination with random non-unison intervals
  --matching-unison           pitchMatching with P1 interval
  --matching-interval         pitchMatching with random non-unison intervals
  --rhythm-offset-detection   rhythmOffsetDetection (early/late judgment)
  --rhythm-matching           continuousRhythmMatching (tap timing accuracy)

Without any discipline flags, generates records distributed across all 6 disciplines.

Usage:
    python3 bin/generate-test-data.py                              # 100 records, all disciplines
    python3 bin/generate-test-data.py --discrimination-unison      # 100 discrimination-unison
    python3 bin/generate-test-data.py --rhythm-offset-detection    # 100 rhythm offset detection
    python3 bin/generate-test-data.py --count 50 output.csv        # 50 records to custom path

Then import the CSV in the app via Settings > Import Training Data (merge mode).
"""

import argparse
import csv
import random
from datetime import datetime, timedelta, timezone

METADATA_LINE = "# peach-export-format:3"

# Full 19-column header matching CSVExportSchema column assembly order:
# common (2) + pitch discrimination (8) + pitch matching (2)
# + rhythm offset detection (2) + continuous rhythm matching (5)
HEADER = [
    "trainingType", "timestamp",
    "referenceNote", "referenceNoteName",
    "targetNote", "targetNoteName",
    "interval", "tuningSystem",
    "centOffset", "isCorrect",
    "initialCentOffset", "userCentError",
    "tempoBPM", "offsetMs",
    "meanOffsetMs",
    "meanOffsetMsPosition0", "meanOffsetMsPosition1",
    "meanOffsetMsPosition2", "meanOffsetMsPosition3",
]

COLUMN_COUNT = len(HEADER)

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


def random_tempo_bpm() -> int:
    return random.randint(60, 200)


def random_offset_ms() -> float:
    """Signed offset: negative = early, positive = late."""
    magnitude = round(random.uniform(5, 150), 1)
    return magnitude * random.choice([-1, 1])


def random_mean_offset_ms() -> float:
    """Mean offset across all positions in a continuous rhythm exercise."""
    return round(random.uniform(-80, 80), 1)


def random_position_offset_ms():
    """Per-position mean offset; occasionally None to simulate missing data."""
    if random.random() < 0.15:
        return None
    return round(random.uniform(-100, 100), 1)


def empty_row(training_type: str, timestamp: datetime) -> list:
    """Create a row pre-filled with empties for all 19 columns."""
    row = [""] * COLUMN_COUNT
    row[0] = training_type
    row[1] = iso_timestamp(timestamp)
    return row


def pitch_discrimination_row(timestamp: datetime, cent_offset: float,
                             interval_abbrev: str, ref_note: int,
                             target_note: int) -> list:
    row = empty_row("pitchDiscrimination", timestamp)
    row[2] = str(ref_note)
    row[3] = midi_name(ref_note)
    row[4] = str(target_note)
    row[5] = midi_name(target_note)
    row[6] = interval_abbrev
    row[7] = "equalTemperament"
    row[8] = f"{cent_offset:.1f}"
    row[9] = random.choice(["true", "false"])
    return row


def pitch_matching_row(timestamp: datetime, initial_cent_offset: float,
                       user_cent_error: float, interval_abbrev: str,
                       ref_note: int, target_note: int) -> list:
    row = empty_row("pitchMatching", timestamp)
    row[2] = str(ref_note)
    row[3] = midi_name(ref_note)
    row[4] = str(target_note)
    row[5] = midi_name(target_note)
    row[6] = interval_abbrev
    row[7] = "equalTemperament"
    row[10] = f"{initial_cent_offset:.1f}"
    row[11] = f"{user_cent_error:.1f}"
    return row


def rhythm_offset_detection_row(timestamp: datetime) -> list:
    row = empty_row("rhythmOffsetDetection", timestamp)
    row[9] = random.choice(["true", "false"])  # isCorrect (shared column)
    row[12] = str(random_tempo_bpm())
    row[13] = f"{random_offset_ms():.1f}"
    return row


def continuous_rhythm_matching_row(timestamp: datetime) -> list:
    row = empty_row("continuousRhythmMatching", timestamp)
    row[12] = str(random_tempo_bpm())
    row[14] = f"{random_mean_offset_ms():.1f}"
    for i in range(4):
        val = random_position_offset_ms()
        if val is not None:
            row[15 + i] = f"{val:.1f}"
    return row


def make_row(discipline: str, timestamp: datetime) -> list:
    ref = random_ref_note()

    if discipline == "discrimination-unison":
        return pitch_discrimination_row(timestamp, random_cent_offset(), "P1", ref, ref)

    elif discipline == "discrimination-interval":
        abbrev, semitones = random_interval()
        target = ref + semitones
        if target > 127:
            target = ref - semitones
        return pitch_discrimination_row(timestamp, random_cent_offset(), abbrev, ref, target)

    elif discipline == "matching-unison":
        return pitch_matching_row(timestamp, random_initial_cent_offset(),
                                  random_user_cent_error(), "P1", ref, ref)

    elif discipline == "matching-interval":
        abbrev, semitones = random_interval()
        target = ref + semitones
        if target > 127:
            target = ref - semitones
        return pitch_matching_row(timestamp, random_initial_cent_offset(),
                                  random_user_cent_error(), abbrev, ref, target)

    elif discipline == "rhythm-offset-detection":
        return rhythm_offset_detection_row(timestamp)

    elif discipline == "rhythm-matching":
        return continuous_rhythm_matching_row(timestamp)

    else:
        raise ValueError(f"Unknown discipline: {discipline}")


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


def generate_records(disciplines: list[str], count: int) -> list:
    timestamps = generate_timestamps(count)
    rows = []

    for i, ts in enumerate(timestamps):
        discipline = disciplines[i % len(disciplines)]
        rows.append(make_row(discipline, ts))

    return rows


ALL_DISCIPLINES = [
    "discrimination-unison", "discrimination-interval",
    "matching-unison", "matching-interval",
    "rhythm-offset-detection", "rhythm-matching",
]

# Map from training type + distinguishing field to display name
DISCIPLINE_CLASSIFIERS = {
    ("pitchDiscrimination", "P1"): "discrimination-unison",
    ("pitchDiscrimination", None): "discrimination-interval",
    ("pitchMatching", "P1"): "matching-unison",
    ("pitchMatching", None): "matching-interval",
    ("rhythmOffsetDetection", None): "rhythm-offset-detection",
    ("continuousRhythmMatching", None): "rhythm-matching",
}


def classify_row(row: list) -> str:
    training_type = row[0]
    interval = row[6]

    if training_type in ("pitchDiscrimination", "pitchMatching"):
        key = (training_type, "P1" if interval == "P1" else None)
    else:
        key = (training_type, None)

    return DISCIPLINE_CLASSIFIERS.get(key, training_type)


def main():
    parser = argparse.ArgumentParser(
        description="Generate CSV test data for Peach training disciplines.")
    parser.add_argument("output", nargs="?", default="test-data.csv",
                        help="Output CSV file path (default: test-data.csv)")
    parser.add_argument("--count", type=int, default=100,
                        help="Number of records to generate (default: 100)")
    parser.add_argument("--discrimination-unison", action="store_true",
                        help="Generate pitch discrimination unison records")
    parser.add_argument("--discrimination-interval", action="store_true",
                        help="Generate pitch discrimination interval records")
    parser.add_argument("--matching-unison", action="store_true",
                        help="Generate pitch matching unison records")
    parser.add_argument("--matching-interval", action="store_true",
                        help="Generate pitch matching interval records")
    parser.add_argument("--rhythm-offset-detection", action="store_true",
                        help="Generate rhythm offset detection records")
    parser.add_argument("--rhythm-matching", action="store_true",
                        help="Generate continuous rhythm matching records")
    args = parser.parse_args()

    disciplines = []
    if args.discrimination_unison:
        disciplines.append("discrimination-unison")
    if args.discrimination_interval:
        disciplines.append("discrimination-interval")
    if args.matching_unison:
        disciplines.append("matching-unison")
    if args.matching_interval:
        disciplines.append("matching-interval")
    if args.rhythm_offset_detection:
        disciplines.append("rhythm-offset-detection")
    if args.rhythm_matching:
        disciplines.append("rhythm-matching")

    if not disciplines:
        disciplines = list(ALL_DISCIPLINES)

    rows = generate_records(disciplines, args.count)

    with open(args.output, "w", newline="") as f:
        f.write(METADATA_LINE + "\n")
        writer = csv.writer(f)
        writer.writerow(HEADER)
        writer.writerows(rows)

    # Count per discipline
    discipline_counts = {}
    for row in rows:
        key = classify_row(row)
        discipline_counts[key] = discipline_counts.get(key, 0) + 1

    print(f"Written {len(rows)} records to {args.output}")
    for discipline, cnt in sorted(discipline_counts.items()):
        print(f"  {discipline}: {cnt} records")
    print()
    print("Import via: Settings > Import Training Data > Merge")


if __name__ == "__main__":
    main()
