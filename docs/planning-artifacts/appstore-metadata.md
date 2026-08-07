# App Store Metadata

Final copy for App Store Connect. Two locales: English (primary) and German.
Character counts are shown for each field next to the App Store limit.

---

## English (en-US)

### Name (limit: 30)

`Peach Ear Trainer`

Length: 17

App Store Connect name; bare "Peach" was taken. Home-screen display name remains "Peach" via `CFBundleDisplayName`.

### Subtitle (limit: 30)

`Ear Training for Musicians`

Length: 26

### Keywords (limit: 100)

`pitch,intonation,interval,tuning,midi,perception,singer,choir,violin,cello,timing`

Length: 81

### Description (limit: 4,000)

```
Peach is an ear-training app. It generates short exercises about pitch and timing, records your responses, and adjusts the difficulty over time.

The training disciplines:

• Compare Pitch — Two notes play; you decide which is higher.
• Match Pitch — Adjust a slider until the note matches the reference.
• Compare Intervals — An interval plays; you judge whether it is in tune.
• Match Intervals — Adjust the second note to form the target interval.
• Compare Timing — A short rhythmic pattern plays; you decide whether one note came early or late.

The algorithm narrows the cent difference between notes as your responses become more accurate. In Compare Timing it narrows the timing offset the same way.

The Profile screen shows per-discipline progress charts, summary statistics, and trend indicators. The home screen shows a small progress sparkline next to each discipline.

Settings:

• Equal Temperament (12-TET) and Just Intonation tuning systems.
• MIDI input from a connected keyboard or controller (Bluetooth, USB, or Network MIDI).
• Multiple selectable sounds: piano, strings, sine wave, and others.
• CSV export and import of your training data.

Peach runs on the device. There is no account, no sign-up, no analytics, and no tracking. Training data stays on the device unless you export it manually.

The same app runs on iPhone, iPad, and Mac. Data does not sync between devices automatically; transfer it via CSV export and import if you need to.

There are no scores, levels, or streaks.
```

Length: 1,509

---

## German (de-DE)

### Name (limit: 30)

`Peach Gehörtrainer`

Length: 18

App Store Connect name (parallel to EN); home-screen display name remains "Peach".

### Subtitle (limit: 30)

`Gehörbildung für Musiker:innen`

Length: 30

Uses the colon form for gender-inclusive phrasing; 30-char limit precludes the longer "Musiker und Musikerinnen" workaround.

### Keywords (limit: 100)

`tonhöhe,intervall,intonation,stimmung,midi,chor,gesang,geige,cello,bratsche,timing`

Length: 82

### Description (limit: 4,000)

```
Peach ist eine Gehörbildungs-App. Sie erzeugt kurze Übungen zu Tonhöhe und Timing, speichert deine Antworten und passt die Schwierigkeit im Laufe der Zeit an.

Die Übungsdisziplinen:

• Tonhöhe vergleichen — Zwei Töne erklingen; du entscheidest, welcher höher ist.
• Tonhöhe treffen — Stelle einen Schieberegler so ein, dass der Ton den Referenzton trifft.
• Intervalle vergleichen — Ein Intervall erklingt; du beurteilst, ob es sauber ist.
• Intervalle treffen — Stelle den zweiten Ton so ein, dass er das Zielintervall ergibt.
• Timing vergleichen — Ein kurzes rhythmisches Muster erklingt; du entscheidest, ob ein Ton zu früh oder zu spät kam.

Der Algorithmus verkleinert den Cent-Unterschied zwischen den Tönen, sobald deine Antworten genauer werden. In der Disziplin Timing vergleichen verkleinert er entsprechend die zeitliche Abweichung.

Auf dem Profil-Screen siehst du pro Disziplin Verlaufsdiagramme, Statistiken und Trendangaben. Auf dem Startbildschirm zeigt eine kleine Verlaufsgrafik den Fortschritt je Disziplin.

Einstellungen:

• Stimmsysteme: gleichstufige Stimmung (12-TET) und reine Stimmung.
• MIDI-Eingabe von einem angeschlossenen Keyboard oder Controller (Bluetooth, USB oder Netzwerk-MIDI).
• Mehrere auswählbare Klänge: Klavier, Streicher, Sinuston und weitere.
• CSV-Export und -Import deiner Übungsdaten.

Peach läuft vollständig auf dem Gerät. Kein Konto, keine Registrierung, keine Analytik, kein Tracking. Übungsdaten verlassen das Gerät nur, wenn du sie manuell exportierst.

Dieselbe App läuft auf iPhone, iPad und Mac. Die Daten werden nicht automatisch zwischen Geräten synchronisiert; übertrage sie bei Bedarf per CSV-Export und -Import.

Es gibt keine Punkte und keine Level.
```

Length: 1,713

---

## App Review Notes (App Store Connect → App Review → Notes)

Plain-text notes for App Store reviewers. Targets the "Notes" field on the App Review submission page (4,000-character limit). Written for a reviewer who is not a musician.

```
What Peach is

Peach is an ear-training app for musicians. It covers pitch perception and the timing of notes within a rhythmic pattern. The app generates short exercises, records the user's responses, and adjusts the difficulty as accuracy improves.

How to use it

Launch the app. The Start screen shows training disciplines grouped into sections (Pitch, Intervals, Rhythm). Tap a discipline to begin a session — a sequence of short trials, a few seconds each. After a few completed sessions, the Profile screen displays per-discipline progress charts and statistics. On a fresh install the Profile screen is empty by design; it requires data from completed sessions to draw anything.

The training disciplines

- Compare Pitch — Two notes play; tap "Higher" or "Lower" to indicate which one was higher.
- Match Pitch — A reference note plays; drag a vertical slider until your note matches the reference, then release to submit.
- Compare Intervals — Like Compare Pitch, but the two notes are separated by a musical interval (for example a fifth) instead of a small pitch difference.
- Match Intervals — Like Match Pitch, but the target is a specific interval above or below the reference note.
- Compare Timing — A short rhythmic pattern plays with one note shifted slightly early or late; tap "Early" or "Late" to indicate which.

Non-obvious interactions

- MIDI input is optional and auto-detected. Every discipline works fully with on-screen controls. If a MIDI keyboard or controller is connected (USB, Bluetooth, or Network MIDI), the app accepts input from it: the pitch-bend wheel adjusts pitch in the Match disciplines. No setup or pairing flow inside the app.
- Sound source and tuning system are selectable in Settings (piano, strings, sine wave, and others; Equal Temperament or Just Intonation).
- CSV export and import are in Settings → Data, for backup or transfer between devices.
- Reset in Settings permanently deletes all training data.

Privacy and data

- No account, no sign-up, no login.
- No network access. No analytics, no tracking, no advertising.
- All training data is stored on the device using SwiftData (Apple's local persistence framework). It leaves the device only via the manual CSV export.
- The app is free and contains no in-app purchases.

Platforms

The same app runs on iPhone, iPad, and Mac. Data does not sync between devices automatically; CSV export and import is the supported transfer path.

Mac menus

The macOS build is a single-window app and adds menu-bar commands that mirror on-screen actions:

- Training — start/stop the active session (⌘T), toggle auto-start, and select a discipline by name.
- Profile — open the Profile screen (⇧⌘P).
- File — Import and Export Training Data (CSV).
- Peach › Settings... (⌘,) and the standard Help menu (per-discipline help).

All on-screen interactions described above work on Mac with mouse or trackpad.
```

Length: 2,901 characters / 475 words

---

## Notes for Upload

- Character counts are measured against the raw text inside the code fences using Python `len()` on the stripped string. App Store Connect counts grapheme clusters, which match for ASCII and standard German diacritics. Re-check after any edits.
- Apple expects keywords as a single comma-separated string. Apple does count spaces in the 100-char keyword field, so omitting spaces between terms maximises the term budget.
- Apple already indexes the app name (`Peach Ear Trainer` / `Peach Gehörtrainer`) and subtitle words for search; those terms are intentionally excluded from the keyword list.
- The German keyword list intentionally uses colloquial instrument names (`geige`, `bratsche`) rather than the formal forms (`violine`, `viola`); App Store search queries in German skew colloquial.
- App Review Notes are submitted in English only — App Store Connect provides a single notes field per submission, not per locale.
