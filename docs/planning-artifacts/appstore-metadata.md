# App Store Metadata

Final copy for App Store Connect. Two locales: English (primary) and German.
Character counts are shown for each field next to the App Store limit.

---

## English (en-US)

### Subtitle (limit: 30)

`Ear Training for Musicians`

Length: 26

### Keywords (limit: 100)

`pitch,intonation,interval,tuning,rhythm,midi,perception,solfege,singer,choir,violin,cello`

Length: 89

### Description (limit: 4,000)

```
Peach is an ear-training app. It generates short exercises that ask you to compare or produce pitches and rhythmic offsets, records your responses, and adjusts the difficulty over time.

The app contains six training disciplines:

• Compare Pitch — Two notes play; you decide which is higher.
• Match Pitch — Adjust a slider until the note matches the reference.
• Compare Intervals — An interval plays; you judge whether it is in tune.
• Match Intervals — Adjust the second note to form the target interval.
• Compare Timing — A note plays; you decide whether it arrives early or late.
• Fill the Gap — Tap the missing beat at the right moment in a repeating pattern.

For pitch tasks, the algorithm narrows the cent difference between notes as your responses become more accurate. For rhythm tasks, it narrows the millisecond offset and tracks early and late deviations separately at each tempo.

The Profile screen shows per-discipline progress charts, summary statistics, and trend indicators. The home screen shows a small progress sparkline next to each discipline.

Settings:

• Equal Temperament (12-TET) and Just Intonation tuning systems.
• MIDI input from a connected keyboard or controller (Bluetooth, USB, or Network MIDI).
• Multiple sound sources via a SoundFont engine: piano, strings, sine wave, and others.
• CSV export and import of your training data.

Peach runs on the device. There is no account, no sign-up, no analytics, and no tracking. Training data stays on the device unless you export it manually.

The same app runs on iPhone, iPad, and Mac. Data does not sync between devices automatically; transfer it via CSV export and import if you need to.

There are no scores, levels, or streaks.
```

Length: 1,718

---

## German (de-DE)

### Subtitle (limit: 30)

`Gehörbildung für Musiker`

Length: 24

### Keywords (limit: 100)

`tonhöhe,intervall,intonation,stimmung,rhythmus,midi,solfeggio,chor,gesang,geige,cello,bratsche`

Length: 94

### Description (limit: 4,000)

```
Peach ist eine Gehörbildungs-App. Sie erzeugt kurze Übungen, in denen du Tonhöhen oder rhythmische Abweichungen vergleichst oder selbst triffst, speichert deine Antworten und passt die Schwierigkeit im Laufe der Zeit an.

Die App enthält sechs Übungsdisziplinen:

• Tonhöhe vergleichen — Zwei Töne erklingen; du entscheidest, welcher höher ist.
• Tonhöhe treffen — Stelle einen Schieberegler so ein, dass der Ton den Referenzton trifft.
• Intervalle vergleichen — Ein Intervall erklingt; du beurteilst, ob es sauber ist.
• Intervalle treffen — Stelle den zweiten Ton so ein, dass er das Zielintervall ergibt.
• Timing vergleichen — Ein Ton erklingt; du entscheidest, ob er zu früh oder zu spät kommt.
• Lücke füllen — Tippe den fehlenden Schlag in einem wiederkehrenden Muster im richtigen Moment.

Bei Tonhöhenaufgaben verkleinert der Algorithmus den Cent-Unterschied zwischen den Tönen, sobald deine Antworten genauer werden. Bei Rhythmusaufgaben verkleinert er den Millisekundenversatz und behandelt zu frühe und zu späte Abweichungen pro Tempo getrennt.

Auf dem Profil-Screen siehst du pro Disziplin Verlaufsdiagramme, Statistiken und Trendangaben. Auf dem Startbildschirm zeigt eine kleine Verlaufsgrafik den Fortschritt je Disziplin.

Einstellungen:

• Stimmsysteme: gleichstufige Stimmung (12-TET) und reine Stimmung.
• MIDI-Eingabe von einem angeschlossenen Keyboard oder Controller (Bluetooth, USB oder Netzwerk-MIDI).
• Mehrere Klangquellen über eine SoundFont-Engine: Klavier, Streicher, Sine Wave und weitere.
• CSV-Export und -Import deiner Übungsdaten.

Peach läuft vollständig auf dem Gerät. Kein Konto, keine Registrierung, keine Analytik, kein Tracking. Übungsdaten verlassen das Gerät nur, wenn du sie manuell exportierst.

Dieselbe App läuft auf iPhone, iPad und Mac. Die Daten werden nicht automatisch zwischen Geräten synchronisiert; übertrage sie bei Bedarf per CSV-Export und -Import.

Es gibt keine Punkte, keine Level und keine Streaks.
```

Length: 1,962

---

## Notes for Upload

- Character counts are measured against the raw text inside the code fences using Python `len()` on the stripped string. App Store Connect counts grapheme clusters, which match for ASCII and standard German diacritics. Re-check after any edits.
- Apple expects keywords as a single comma-separated string. Apple does count spaces in the 100-char keyword field, so omitting spaces between terms maximises the term budget.
- Apple already indexes the app name (`Peach`) and subtitle words for search; those terms are intentionally excluded from the keyword list.
- The German keyword list intentionally uses colloquial instrument names (`geige`, `bratsche`) rather than the formal forms (`violine`, `viola`); App Store search queries in German skew colloquial.
- `Solfeggio` (DE) and `solfege` (EN) are spelled per the most-searched form on the App Store.
- The DE description retains `Sine Wave` (English) for the sound-source example because the SoundFont preset name is baked in English and is shown verbatim in the in-app picker.
