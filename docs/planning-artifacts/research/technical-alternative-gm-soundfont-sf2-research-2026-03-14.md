---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: []
workflowType: 'research'
lastStep: 1
research_type: 'technical'
research_topic: 'Alternative GM SoundFont (SF2) files to replace GeneralUser GS v2.0.3'
research_goals: 'Find an SF2 file whose Grand Piano samples do not trigger the AVAudioUnitSampler crash on A18 Pro, while meeting license, size, quality, and instrument coverage requirements for a commercial iOS ear training app'
user_name: 'Michael'
date: '2026-03-14'
web_research_enabled: true
source_verification: true
---

# Alternative GM SoundFont (SF2) Research

**Date:** 2026-03-14
**Author:** Michael
**Research Type:** Technical

---

## Executive Summary

This research evaluates alternative GM SoundFont (SF2) files to replace GeneralUser GS v2.0.3, which crashes on iPhone 17 Pro (A18 Pro) when playing piano presets via AVAudioUnitSampler. The crash is in Apple's ARM-optimized sample interpolation code — confirmed for Grand Piano, Bright Piano, Bell Piano, and Electric Grand Piano presets. Non-piano presets play without issue. The crash does not occur on iPhone 11 Pro (A13) or simulators.

**Nine candidates were evaluated** against hard criteria (license, size <50 MB, GM coverage, SF2 format, lossless quality). Key findings from device testing:

- **JNS-GM 2.0 (JNSGM2)** — CC0, 33 MB, full GM. Piano presets **also crash on A18 Pro**. This rules out GeneralUser-GS-specific sample data as the cause; the bug is triggered by characteristics common to piano presets across independent SF2 authors.
- **MuseScore_General** — MIT, 210 MB. Piano presets **do not crash on A18 Pro**, but the piano has an audible string pad layer that makes it unsuitable as-is.
- **FluidR3_GM** — MIT, 141 MB. Piano presets **do not crash on A18 Pro** and sound clean. This is the source of MuseScore_General's piano samples (without the string layering).

**Recommended approach:** Build a custom SF2 in Polyphone combining FluidR3_GM piano presets (confirmed working on A18 Pro) with GeneralUser GS non-piano presets (which never crashed). The custom SF2 should be small enough (~35-40 MB) to commit to the repository. The download script (`bin/download-sf2.sh`) should be extended to download both source SoundFonts to `.cache` for the manual Polyphone assembly step.

**Alternative rendering engines** (bradhowes/SF2Lib, AudioKit DunneAudioKit) were evaluated as fallbacks but are not needed — the crash is avoidable by using FluidR3_GM's piano samples.

**Tooling landscape:** No command-line tool exists for merging presets from multiple SF2 files into one. Polyphone GUI is the standard workflow for SF2 assembly. The SoundFont ecosystem lacks build-pipeline tooling comparable to other software domains.

## Table of Contents

1. [Technical Research Scope Confirmation](#technical-research-scope-confirmation)
2. [Technology Stack Analysis](#technology-stack-analysis)
3. [Integration Patterns Analysis](#integration-patterns-analysis)
4. [Architectural Patterns and Design](#architectural-patterns-and-design)
5. [Implementation Approaches and Sample Sourcing](#implementation-approaches-and-sample-sourcing)
6. [Technical Research Recommendations](#technical-research-recommendations)

## Research Methodology

This research was conducted on 2026-03-14 using:
- **Web search** for current license texts, download sources, community reviews, and file specifications
- **Prior research** from the 2026-02-23 sampled instrument NotePlayer research document
- **Source verification** against GitHub repositories, project homepages, and license files
- **Multi-source validation** for critical claims (especially licensing terms)

All sources are cited inline. Confidence levels (HIGH/MEDIUM/LOW) are noted for uncertain findings.

---

## Technical Research Scope Confirmation

**Research Topic:** Alternative GM SoundFont (SF2) files to replace GeneralUser GS v2.0.3
**Research Goals:** Find an SF2 file whose Grand Piano samples do not trigger the AVAudioUnitSampler crash on A18 Pro, while meeting license, size, quality, and instrument coverage requirements for a commercial iOS ear training app

**Technical Research Scope:**

- Candidate Evaluation - FluidR3_GM, TimGM6mb, Arachno, WeedsGM3, MuseScore_General, Timbres of Heaven, plus others
- License Analysis - Exact license text, commercial iOS compatibility
- Technical Compatibility - SF2 format, AVAudioUnitSampler, known iOS issues
- Quality Assessment - Bit depth, sample rate, sample density, lossless sourcing
- Crash Risk Analysis - A18 Pro bug characteristics and mitigation

**Research Methodology:**

- Current web data with rigorous source verification
- Multi-source validation for critical technical claims
- Confidence level framework for uncertain information
- Comprehensive technical coverage with architecture-specific insights

**Scope Confirmed:** 2026-03-14

## Technology Stack Analysis

### Current Baseline: GeneralUser GS v2.0.3

| Attribute | Value |
|-----------|-------|
| **File size** | 30.7 MB (uncompressed SF2) |
| **Melodic presets** | 261 (full GM + GS extensions) |
| **Drum kits** | 13 |
| **Sample format** | 16-bit PCM, 44.1 kHz |
| **License** | Free for any use including commercial; attribution required |
| **Author** | S. Christian Collins |
| **Source** | [GitHub](https://github.com/mrbumpy409/GeneralUser-GS), [Homepage](https://schristiancollins.com/generaluser.php) |

**Problem:** The Grand Piano preset (bank 0, program 0) reliably crashes on iPhone 17 Pro (A18 Pro) inside AVAudioUnitSampler's ARM-optimized sample interpolation code. Works fine on A13 and all simulators. The crash is in Apple's code — we need an SF2 whose piano samples don't trigger it.

### Candidate Evaluation Matrix

Nine candidates were evaluated against the five hard criteria. The table below shows the pass/fail gate before deeper analysis.

| Candidate | Size | License | GM Coverage | Format | Quality | **Verdict** |
|-----------|------|---------|-------------|--------|---------|-------------|
| **JNS-GM 2.0 (JNSGM2)** | 33.2 MB | CC0 (Public Domain) | Full GM (128) | SF2 | 16-bit PCM | **PASS** |
| **FluidR3_GM** | 141 MB | MIT | Full GM (128+) | SF2 | 16-bit PCM | **FAIL (size)** |
| **MuseScore_General** | 210 MB | MIT | Full GM+ (128+) | SF2 | 16-bit PCM | **FAIL (size)** |
| **TimGM6mb** | 5.7 MB | GPL v2 | Full GM (128) | SF2 | Low density | **FAIL (license)** |
| **Timbres of Heaven** | 250–350 MB | All Rights Reserved | Full GM/GS/XG | SF2 | High | **FAIL (size + license)** |
| **Arachno SoundFont** | 136 MB | Non-commercial only | Full GM (128+9 kits) | SF2 | Good | **FAIL (size + license)** |
| **WeedsGM3** | 55 MB | Unclear (license.txt) | Full GM (128+9 kits) | SF2 | Good | **FAIL (size + license unclear)** |
| **SGM-V2.01** | 236 MB | CC-BY 3.0 | Full GM | SF2 | High | **FAIL (size)** |
| **Airfont 340** | 76.8 MB | WTFPL 2.0 | Full GM | SF2 | Mixed | **FAIL (size)** |

### Detailed Candidate Assessments

#### 1. JNS-GM 2.0 (JNSGM2) — PASSES ALL CRITERIA

| Attribute | Details |
|-----------|---------|
| **Author** | Jordi Navarro Subirana |
| **File size** | 33.19 MB (uncompressed SF2) |
| **License** | CC0 1.0 Universal (Public Domain Dedication) |
| **License text** | "To the extent possible under law, the author has waived all copyright and related or neighboring rights to this work." |
| **Melodic presets** | 128 (full General MIDI) |
| **Instrument coverage** | Piano (8 variants), strings (violin, viola, cello, contrabass, tremolo, pizzicato, harp, timpani), woodwinds (flute, clarinet, oboe, piccolo, recorder, pan flute), brass (trumpet, trombone, French horn, tuba, sax family), guitar (8 variants), bass (8 variants), organs, synths, pads, percussion |
| **Sample quality** | 16-bit PCM (standard SF2 format). Exact sample rate not documented; assumed 44.1 kHz based on standard practice |
| **Known iOS issues** | None documented |
| **Download** | [Polyphone](https://www.polyphone.io/en/soundfonts/instrument-sets/55-jns-gm-2-0), [rKhive](http://rkhive.com) |
| **Community rating** | 4.75/5 stars (Polyphone, 2 reviews) |
| **Last updated** | Unknown (no version history found) |

_Assessment:_ The most permissive license possible (CC0 — no attribution even required). Near-identical file size to GeneralUser GS (33 vs 31 MB). Full GM coverage including all required instrument families. The main unknown is sample quality for sub-cent pitch training — requires hands-on testing.

_Confidence: HIGH for license and size; MEDIUM for quality (no detailed reviews found)_
_Source: [Polyphone](https://www.polyphone.io/en/soundfonts/instrument-sets/55-jns-gm-2-0), [GitHub bratpeki/soundfonts](https://github.com/bratpeki/soundfonts)_

#### 2. FluidR3_GM — FAILS ON SIZE, but viable via pruning

| Attribute | Details |
|-----------|---------|
| **Author** | Frank Wen |
| **File size** | ~141 MB (uncompressed SF2) |
| **License** | MIT License |
| **License text** | "Permission is hereby granted, free of charge, to any person obtaining a copy of this software… to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies…" (standard MIT) |
| **Melodic presets** | 128+ (full GM with GS extensions) |
| **Sample quality** | 16-bit PCM, high multi-sample density. Considered the reference standard for open-source GM SoundFonts |
| **Known iOS issues** | None specific. Used by FluidSynth, the most widely deployed open-source SF2 renderer |
| **Download** | [Musical Artifacts](https://musical-artifacts.com/artifacts/1229), [SourceForge (Piano Booster)](https://sourceforge.net/projects/pianobooster/files/pianobooster/1.0.0/FluidR3_GM.sf2/download) |
| **Last updated** | Original: 2000-2008. GitHub archive: 2021 |
| **Community reputation** | De facto standard. Default SF2 for Linux audio (Fedora, Debian). Basis for MuseScore_General |

_Assessment:_ Excellent quality and license, but 141 MB exceeds the 50 MB limit. However, **pruning to ~20 presets via Polyphone would yield a file well under 50 MB** while preserving the highest-quality samples in the open-source ecosystem. This is the strongest "prune-to-fit" candidate.

_Confidence: HIGH_
_Source: [Musical Artifacts](https://musical-artifacts.com/artifacts/1229), [Fedora Packages](https://packages.fedoraproject.org/pkgs/fluid-soundfont/fluid-soundfont-gm/), [GitHub Jacalz/fluid-soundfont](https://github.com/Jacalz/fluid-soundfont)_

#### 3. MuseScore_General — FAILS ON SIZE, but viable via pruning

| Attribute | Details |
|-----------|---------|
| **Author** | S. Christian Collins (same as GeneralUser GS) |
| **File size** | ~210 MB (SF2), ~36 MB (SF3/compressed) |
| **License** | MIT License |
| **License text** | Standard MIT. Attribution required for: Frank Wen (FluidR3 original), Michael Cowgill (mono conversion), S. Christian Collins (adaptation), Ethan Winer (Temple Blocks), Michael Schorsch (Drumline Cymbals) |
| **Melodic presets** | 128+ (full GM with expression variants across banks 0, 8, 17, 18, 20-51) |
| **Sample quality** | Derived from FluidR3Mono; additional instruments and rebalancing by Collins |
| **Download** | [OSUOSL FTP](https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/) |
| **Last updated** | Version 0.2, 2018-19 |

_Assessment:_ Built by the same author as GeneralUser GS, using FluidR3 as a base with significant additions. Higher quality than GeneralUser GS. MIT license is ideal. At 210 MB it fails the size criterion, but **pruning to ear-training instruments would yield ~30-50 MB**. The key question: since Collins also built GeneralUser GS, do the piano samples share the same source material that triggers the A18 Pro crash? The answer is likely **no** — MuseScore_General's piano is derived from FluidR3 (Frank Wen), not from GeneralUser GS's piano samples.

_Confidence: HIGH for license; MEDIUM for whether piano samples differ enough from GeneralUser GS_
_Source: [MuseScore_General License](https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/MuseScore_General_License.md), [MuseScore Forums](https://musescore.org/en/node/306828)_

#### 4. TimGM6mb — DISQUALIFIED (GPL license)

| Attribute | Details |
|-----------|---------|
| **Author** | Tim Brechbill |
| **File size** | 5.7 MB |
| **License** | **GNU General Public License v2** |
| **Disqualification** | GPL v2 is a viral/copyleft license. Bundling in a commercial iOS app would require releasing the entire app as GPL. This is incompatible with App Store distribution. |

_Source: [Debian package](https://packages.debian.org/sid/timgm6mb-soundfont), [GitHub craffel/pretty-midi](https://github.com/craffel/pretty-midi/blob/main/pretty_midi/TimGM6mb.sf2)_

#### 5. Timbres of Heaven — DISQUALIFIED (license + size)

| Attribute | Details |
|-----------|---------|
| **Author** | Don Allen |
| **File size** | 250–350 MB (varies by version; v3.4 Final is ~320 MB) |
| **License** | **All Rights Reserved.** "May not be distributed on any site without the express written permission of Don Allen." |
| **Disqualification** | Explicit "All Rights Reserved" copyright. No commercial redistribution permitted without written permission. Also far exceeds 50 MB limit. |

_Source: [Midkar.com](https://www.midkar.com/SoundFonts/index.html), [Internet Archive](https://archive.org/details/toh-gmgsxg)_

#### 6. Arachno SoundFont — DISQUALIFIED (license + size)

| Attribute | Details |
|-----------|---------|
| **Author** | Maxime Abbey |
| **File size** | 136 MB (decompressed SF2) |
| **License** | **Non-commercial use only.** "Copyright © 2000-2026 Maxime Abbey. All rights reserved. Any reproduction is forbidden without authorization." Uses portions from other authors — commercial redistribution not permitted. |
| **Disqualification** | Non-commercial restriction explicitly prohibits bundling in a commercial app. Also exceeds 50 MB limit. |

_Source: [Arachnosoft](https://www.arachnosoft.com/main/soundfont.php), [Musical Artifacts](https://musical-artifacts.com/artifacts/2045)_

#### 7. WeedsGM3 — DISQUALIFIED (size + license unclear)

| Attribute | Details |
|-----------|---------|
| **Author** | Rich "Weeds" Nagel |
| **File size** | 54.9 MB |
| **License** | License text exists in `WeedsGM3.License.txt` but is not publicly available online. No explicit commercial use permission found in any community discussion. |
| **Disqualification** | At 55 MB, marginally exceeds the 50 MB limit. License terms are opaque — no verifiable permission for commercial redistribution. The author released this in 2010 and does not appear to be actively reachable for clarification. |

_Source: [VOGONS](https://www.vogons.org/viewtopic.php?t=24355), [Doomworld](https://www.doomworld.com/forum/topic/51104-weeds-general-midi-soundfont-v30/)_

#### 8. SGM-V2.01 — DISQUALIFIED (size)

| Attribute | Details |
|-----------|---------|
| **Author** | Shan |
| **File size** | 236 MB |
| **License** | CC-BY 3.0 (acceptable) |
| **Disqualification** | 236 MB far exceeds the 50 MB limit. Could be pruned, but FluidR3_GM and MuseScore_General are better prune candidates due to wider adoption and MIT license. |

_Source: [Internet Archive](https://archive.org/details/SGM-V2.01), [Polyphone](https://www.polyphone.io/en/soundfonts/instrument-sets/256-sgm-v2-01)_

#### 9. Airfont 340 — DISQUALIFIED (size)

| Attribute | Details |
|-----------|---------|
| **Author** | Milton Paredes |
| **File size** | 76.8 MB |
| **License** | WTFPL 2.0 (Do What The F*** You Want To Public License — permissive, but unconventional) |
| **Disqualification** | 76.8 MB exceeds the 50 MB limit. The WTFPL license is technically permissive but has untested legal standing and may not hold up in all jurisdictions. |

_Source: [Musical Artifacts](https://musical-artifacts.com/artifacts/633), [Internet Archive](https://archive.org/details/free-soundfonts-sf2-2019-04)_

### Technology Adoption Summary

| Approach | Candidates | Effort | Risk |
|----------|-----------|--------|------|
| **Drop-in replacement** (use as-is) | JNS-GM 2.0 (33 MB) | Low | Medium — untested quality, piano may still crash |
| **Prune to fit** (extract ~20 presets) | FluidR3_GM (MIT), MuseScore_General (MIT) | Medium — requires Polyphone workflow | Low — highest-quality samples, different piano source |
| **Hybrid** (drop-in + prune backup) | JNS-GM 2.0 first, FluidR3_GM pruned as fallback | Medium | Lowest — two independent piano sample sources |

## Integration Patterns Analysis

### A18 Pro Crash Characterization

**Confirmed crash behavior (from device testing):**

| SF2 File | Preset | iPhone 17 Pro (A18) | iPhone 11 Pro (A13) | Simulator |
|----------|--------|:-------------------:|:-------------------:|:---------:|
| GeneralUser GS | Grand Piano (0:0) | CRASH | OK | OK |
| GeneralUser GS | Bright Piano (0:1) | CRASH | OK | OK |
| GeneralUser GS | Bell Piano | CRASH | OK | OK |
| GeneralUser GS | Electric Grand Piano (0:2) | CRASH | OK | OK |
| GeneralUser GS | Non-piano presets | OK | OK | OK |
| **JNSGM2** | **Acoustic Piano (0:0)** | **CRASH** | **OK** | — |
| **MuseScore_General** | **Piano (0:0)** | **OK** (string pad artifact) | **OK** | — |
| **FluidR3_GM** | **Piano (0:0)** | **OK** | **OK** | — |

**Key finding:** Two independent SF2 files (GeneralUser GS and JNSGM2, different authors, different samples) both crash on piano presets on A18 Pro. One SF2 (FluidR3_GM) does not crash. MuseScore_General (derived from FluidR3_GM) also does not crash but has an undesirable string pad layer.

**Pattern:** The crash is NOT specific to one SF2 file's piano samples — it's triggered by characteristics common to some piano implementations but not others. Possible triggers:

1. **Large sample zones** — Piano presets typically have the most samples and largest zones in a GM SoundFont (multi-velocity layers across the full 88-key range). GeneralUser GS packs this into 31 MB, so the piano samples may use aggressive zone splitting or unusual loop configurations to save space.
2. **Sample alignment** — Apple's ARM-optimized interpolation code may assume specific memory alignment that GeneralUser GS's piano samples violate.
3. **Loop point edge cases** — Piano samples with very long loop regions or loop endpoints near the end of the sample data may trigger an off-by-one in Apple's NEON-optimized rendering path.
4. **Sample rate mismatch** — If some piano samples use a different sample rate than the audio engine expects, the resampling code may read past buffer boundaries.

_Confidence: MEDIUM — these are informed hypotheses based on the crash pattern (piano-only, ARM-only), not confirmed root causes._

### AVAudioUnitSampler Compatibility Landscape

AVAudioUnitSampler is Apple's built-in SF2/DLS renderer. It delegates all sample rendering to Apple's Audio Toolbox framework, which uses ARM NEON-optimized code on physical devices and x86 code on simulators. Key known issues:

- **Malformed SF2 crash** — Uncatchable. If the SF2 file has spec violations, the sampler crashes the process. No try/catch, no signal handler can save you. ([Apple Developer Forums](https://developer.apple.com/forums/thread/60265))
- **File handle exhaustion** — Multiple sampler instances can exceed the 256 soft file handle limit. ([Apple Developer Forums](https://forums.developer.apple.com/forums/thread/709564))
- **Post-interruption corruption** — After audio session interruption (phone call), sound may be corrupted until the SF2 is reloaded. ([Gene De Lisa](https://www.rockhoppertech.com/blog/the-great-avaudiounitsampler-workout/))

The A18 Pro crash does not match any of these documented patterns. It appears to be a previously unreported bug in the ARM rendering path, triggered by specific sample characteristics.

_Source: [Apple AVAudioUnitSampler Documentation](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler), [Infinum AUSampler Documentation](https://infinum.com/blog/ausampler-missing-documentation/)_

### Alternative Rendering Engines (if SF2 swap fails)

| Engine | License | SF2 Support | SF3 | Effort | Solves Crash? |
|--------|---------|:-----------:|:---:|--------|:-------------:|
| **AVAudioUnitSampler** (current) | Apple | Yes | No | None | No (it IS the crash) |
| **bradhowes/SF2Lib** | MIT | Yes | No | High — rewrite SoundFontNotePlayer, new SPM dependency | Yes — independent C++ renderer |
| **AudioKit DunneAudioKit/Sampler** | MIT | No (SFZ only) | No | High — SF2→SFZ conversion, large dependency | Yes — independent C++ renderer |
| **AudioKit AppleSampler** | MIT | Yes | No | Medium — wrapper only | **No** — delegates to AVAudioUnitSampler |
| **FluidSynth** | **LGPL** | Yes | Yes | High — C library integration | Yes — but LGPL is borderline for iOS |
| **oxisynth (Rust)** | MIT | Yes | Yes | Very high — Rust FFI bridge | Yes |

_Recommendation: Only escalate to an alternative renderer if the SF2 swap approach fails entirely (i.e., multiple independent SF2 files all crash on A18 Pro piano presets). SF2Lib is the most viable fallback — MIT license, active maintenance (v8.9.0, Feb 2026), Swift 6 bridging._

## Architectural Patterns and Design

### Workaround Strategy Tiers

**Tier 1: Drop-in SF2 replacement (lowest effort)**
Replace `GeneralUser-GS.sf2` with `Jnsgm2.sf2` in the app bundle. Zero code changes. Test on A18 Pro.

**Tier 2: Surgical piano swap (medium effort)**
If JNSGM2's piano also crashes, but its non-piano presets are acceptable:
1. Open GeneralUser-GS.sf2 in Polyphone
2. Delete all piano-family presets (programs 0-7)
3. Import piano presets from FluidR3_GM (MIT license, different piano samples)
4. Save as a new SF2 file
5. This gives us GeneralUser GS quality for 253 presets + FluidR3 piano

**Tier 3: Pruned FluidR3_GM (medium effort)**
Extract ~20 presets from FluidR3_GM using Polyphone → save as a new SF2 under 50 MB. Entirely different sample source from GeneralUser GS.

**Tier 4: Dual-SF2 architecture (medium-high effort)**
Modify `SoundFontNotePlayer` to load from two different SF2 files — one for piano, one for everything else. Requires a small code change to `loadPreset()` to select the SF2 URL based on the program number.

**Tier 5: Replace rendering engine (high effort)**
Adopt bradhowes/SF2Lib as an AUv3 MIDI instrument, replacing AVAudioUnitSampler entirely. This definitively eliminates the Apple rendering bug but requires rewriting `SoundFontNotePlayer` and adding a C++/Swift SPM dependency.

### Impact on SoundFontLibrary and Preset Discovery

`SoundFontLibrary` (`Peach/Core/Audio/SoundFontLibrary.swift`) discovers presets from the bundled SF2 using `SF2PresetParser`. A drop-in replacement (Tier 1) requires zero code changes — the library parses whatever SF2 is bundled. Key differences to account for:

| Aspect | GeneralUser GS | JNSGM2 |
|--------|---------------|--------|
| Melodic presets | 261 (GM + GS banks 0, 8) | 128 (GM bank 0 only) |
| Bank structure | Multi-bank (0, 8) | Single bank (0) |
| Preset names | Detailed (e.g., "Stereo Grand") | Standard GM names |
| Default preset | Bank 8, Program 80 (Sine Wave) | Not available — no bank 8 |

**Critical issue:** The current default preset is Sine Wave at bank 8, program 80 (`SoundFontNotePlayer.defaultPresetBank = 8`). JNSGM2 only has bank 0 presets. The default will fail to load, falling back to... what? Let me check.

The `ensurePresetLoaded()` code at line 138-148 falls back to `defaultPresetProgram` (80) and `defaultPresetBank` (8) if the user's `soundSource` setting can't be loaded. If that also fails, the `loadSoundBankInstrument` call will throw, and the play will fail with an error.

**Required code change for JNSGM2:** Update the default preset to use bank 0 instead of bank 8. Program 80 in bank 0 is "Ocarina" in GM — not ideal. A more sensible default for an ear training app would be program 0 (Grand Piano) or another common preset. However, since we're specifically trying to test whether JNSGM2's piano crashes, the default should be set to something safe first (e.g., program 48 = String Ensemble 1), and piano tested explicitly.

## Implementation Approaches and Sample Sourcing

### Step-by-Step: Testing JNSGM2 on A18 Pro

#### Prerequisites

- Polyphone SoundFont editor installed (free, [polyphone.io](https://www.polyphone.io/))
- iPhone 17 Pro (A18 Pro) connected for device testing
- Peach project builds and runs on the device

#### Step 1: Download JNSGM2

**Option A — GitHub (direct file, reliable):**
```
curl -L -o /tmp/Jnsgm2.sf2 \
  "https://github.com/wrightflyer/SF2_SoundFonts/raw/master/Jnsgm2.sf2"
```

**Option B — Polyphone website:**
Visit [polyphone.io/en/soundfonts/instrument-sets/55-jns-gm-2-0](https://www.polyphone.io/en/soundfonts/instrument-sets/55-jns-gm-2-0) (requires free account).

**Option C — Archive.org (older v1):**
```
curl -L -o /tmp/Jnsgm.sf2 \
  "https://archive.org/download/free-soundfonts-sf2-2019-04/Jnsgm.sf2"
```
Note: This is `Jnsgm.sf2` (v1, 31.7 MB), not `Jnsgm2.sf2` (v2, 33.2 MB). Prefer v2 from GitHub.

#### Step 2: Inspect in Polyphone

Open `Jnsgm2.sf2` in Polyphone to verify:
1. Preset 0 (Grand Piano) exists and has sample zones
2. All 128 GM presets are present
3. No obvious issues (empty presets, missing samples)
4. Check the piano preset's sample rate, bit depth, zone count

#### Step 3: Swap into Peach (temporary, for testing only)

```bash
# Back up current SF2
cp Peach/Resources/GeneralUser-GS.sf2 Peach/Resources/GeneralUser-GS.sf2.bak

# Copy JNSGM2 with the expected filename
cp /tmp/Jnsgm2.sf2 Peach/Resources/GeneralUser-GS.sf2
```

**Important:** This renames the file to match the existing bundle reference. No code changes needed for the initial crash test.

**However**, note the bank structure difference: JNSGM2 has no bank 8. The app's default preset (bank 8, program 80 = Sine Wave) will fail to load. For a quick test:

1. Temporarily change `SoundFontNotePlayer.defaultPresetBank` from `8` to `0` and `defaultPresetProgram` from `80` to a safe preset like `48` (String Ensemble 1)
2. Or set the user's `soundSource` setting to `sf2:0:0` (Grand Piano) before running — this is the preset we specifically want to crash-test

#### Step 4: Build and run on iPhone 17 Pro

```bash
# Build for device
bin/build.sh
```

Then deploy to iPhone 17 Pro and:
1. Navigate to Settings → select Grand Piano (sf2:0:0) as the sound source
2. Start a training session — this will trigger `startNote()` on the piano preset
3. **If it plays without crashing:** JNSGM2's piano avoids the bug. Proceed to quality evaluation.
4. **If it crashes:** The A18 Pro bug is not specific to GeneralUser GS's piano samples. Escalate to Tier 2/3.

#### Step 5: Quality evaluation (if Step 4 passes)

Play through all required instrument families and evaluate subjectively:
- Piano — pitch clarity, naturalness
- Strings (program 48-51) — sustain quality, no artifacts
- Woodwinds (programs 68-75) — attack clarity, pitch center
- Brass (programs 56-63) — presence, dynamic range
- Guitar (programs 24-31) — pluck transient, sustain

If quality is acceptable for pitch discrimination training, JNSGM2 becomes the production replacement.

#### Step 6: Restore (if not adopting)

```bash
# Restore original SF2
mv Peach/Resources/GeneralUser-GS.sf2.bak Peach/Resources/GeneralUser-GS.sf2
```

### Fallback: Pruning FluidR3_GM

If JNSGM2 doesn't work out (crash or quality), the fallback is extracting a subset of FluidR3_GM:

1. Download FluidR3_GM.sf2 (141 MB, MIT license) from [Musical Artifacts](https://musical-artifacts.com/artifacts/1229)
2. Open in Polyphone
3. Select all presets **except** the ~20 needed for ear training
4. Delete selected presets
5. Use Tools → "Remove unused elements" to strip orphaned instruments and samples
6. Save as `Peach-FluidR3.sf2`
7. Expected size: ~20-40 MB depending on which presets are kept

**Presets to keep (suggested):**

| Program | Name | Category |
|---------|------|----------|
| 0 | Acoustic Grand Piano | Piano |
| 1 | Bright Acoustic Piano | Piano |
| 4 | Electric Piano 1 | Piano |
| 24 | Acoustic Guitar (nylon) | Guitar |
| 25 | Acoustic Guitar (steel) | Guitar |
| 40 | Violin | Strings |
| 42 | Cello | Strings |
| 48 | String Ensemble 1 | Strings |
| 56 | Trumpet | Brass |
| 57 | Trombone | Brass |
| 60 | French Horn | Brass |
| 61 | Brass Section | Brass |
| 68 | Oboe | Woodwinds |
| 71 | Clarinet | Woodwinds |
| 73 | Flute | Woodwinds |
| 75 | Pan Flute | Woodwinds |
| 80 | Synth Lead (square) | Synth (Sine Wave substitute) |

## Technical Research Recommendations

### Ranked Recommendation (Updated After Device Testing)

**Recommended: Custom SF2 via Polyphone — FluidR3_GM piano + GeneralUser GS non-piano**

- **Why:** Device testing confirmed FluidR3_GM's piano does not crash on A18 Pro. GeneralUser GS's non-piano presets never crashed. Combining them in Polyphone produces a custom SF2 with the best of both: crash-free piano + the full GeneralUser GS instrument set.
- **License:** FluidR3_GM piano is MIT (attribution to Frank Wen). GeneralUser GS non-piano presets retain their existing license (attribution to S. Christian Collins). Both are compatible with commercial iOS distribution.
- **Size:** Estimated ~35-40 MB — small enough to commit to the repository.
- **Effort:** Manual Polyphone assembly (~15-30 minutes, one-time). Download script extended to fetch both source SF2s.

**Fallback: Pure FluidR3_GM pruned to ~20 presets**

- If any GeneralUser GS presets cause issues, fall back to a pure FluidR3_GM subset. MIT license, single attribution.

**Nuclear option: bradhowes/SF2Lib**

- If future Apple updates break more presets and the SF2-swap approach becomes a whack-a-mole game, replace AVAudioUnitSampler entirely with SF2Lib (MIT, v8.9.0, Feb 2026, full SF2 spec, Swift 6 bridging). This eliminates Apple's rendering code as the crash source.

### Risk Assessment (Post-Testing)

**The A18 Pro crash is now well-characterized:**

- Two independent SF2 files (GeneralUser GS, JNSGM2) crash on piano presets
- One SF2 (FluidR3_GM) does not crash on piano presets
- The crash is in Apple's ARM-optimized rendering code, not in our code or the SF2 spec
- The differentiating factor is likely the piano sample data characteristics (zone structure, velocity layering, sample sizes) — FluidR3_GM's piano happens to use a structure that Apple's code handles correctly

**Remaining risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| FluidR3_GM piano stops working on future iOS | Low | High | File Apple Feedback, fall back to SF2Lib |
| Custom SF2 is lost/corrupted | Low | Low | Source SF2s downloadable via script; Polyphone assembly documented |
| FluidR3_GM piano quality insufficient for sub-cent training | Low | Medium | Test during integration; FluidR3 is the highest-regarded open-source GM piano |
| Future instruments also crash on A18 Pro | Very low | Medium | Only piano presets affected across all tested SF2 files |

### Tooling Landscape

No command-line tool exists for merging presets from multiple SF2 files. The SF2 ecosystem relies on GUI editors:

| Tool | Read SF2 | Write SF2 | Merge Presets | Scriptable |
|------|:--------:|:---------:|:-------------:|:----------:|
| **Polyphone** (GUI) | Yes | Yes | Yes (drag-and-drop between open files) | CLI: format conversion only |
| **sf2utils** (Python) | Yes | No | — | — |
| **sf2-split** (C++) | Yes | Per-preset only | No | Yes |
| **sf-creator** (Python) | No | SFZ only | No | Yes |

A fully automated SF2 merge pipeline would require ~500 lines of custom Python SF2 binary writer code — disproportionate to the one-time manual Polyphone assembly. The source SF2 downloads are automated via `bin/download-sf2.sh`.

### Key Sources

- [JNS-GM 2.0 on Polyphone](https://www.polyphone.io/en/soundfonts/instrument-sets/55-jns-gm-2-0)
- [JNSGM2 on GitHub](https://github.com/wrightflyer/SF2_SoundFonts/blob/master/Jnsgm2.sf2)
- [FluidR3 GM+GS on Musical Artifacts](https://musical-artifacts.com/artifacts/1229) — MIT license
- [MuseScore_General License](https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/MuseScore_General_License.md) — MIT license
- [GeneralUser GS on GitHub](https://github.com/mrbumpy409/GeneralUser-GS)
- [bradhowes/SF2Lib](https://github.com/bradhowes/SF2Lib) — MIT, fallback renderer
- [Apple AVAudioUnitSampler Documentation](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler)
- [Polyphone SoundFont Editor](https://www.polyphone.io/)
- [Best Free GM SoundFonts 2026](https://miditoolbox.com/posts/best-free-general-midi-soundfonts-2026)

---

**Research completed:** 2026-03-14
**Sources:** 20+ web searches verified against GitHub repositories, project homepages, license files, and community forums
**Confidence:** HIGH for candidate evaluation and licensing; MEDIUM for crash avoidance prediction (requires device testing)
