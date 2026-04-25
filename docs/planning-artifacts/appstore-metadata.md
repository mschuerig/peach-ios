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
Sharper ears. Better musicianship. Peach trains your perception of pitch and rhythm so that what you hear becomes what you produce — in tune and in time.

Peach is a focused ear-training app for singers and instrumentalists. It builds a personal perceptual profile of your hearing and quietly targets the spots where you are weakest. There are no scores, no levels, and no streaks to chase — every short session simply makes you a little sharper.

SIX TRAINING DISCIPLINES

• Compare Pitch — Two notes play; you decide which is higher.
• Match Pitch — Tune a note with a slider until it matches the reference.
• Compare Intervals — Hear an interval and judge whether it is in tune.
• Match Intervals — Tune the second note to form the target interval.
• Compare Timing — Decide whether a note arrives early or late.
• Fill the Gap — Tap the missing beat at the right moment.

ADAPTIVE BY DESIGN

Peach watches how you respond and adjusts the difficulty for you. As your discrimination narrows, the cent and millisecond differences shrink with it. Rhythm exercises track your accuracy at each tempo and treat early and late deviations independently.

YOUR PERCEPTUAL PROFILE

The Profile screen shows how your hearing maps across the keyboard and across tempos. Trends, summary statistics, and a per-discipline progress sparkline make it easy to see whether your ears are getting sharper.

BUILT FOR REAL MUSICIANS

• Equal Temperament (12-TET) and Just Intonation — train in the system you actually play in.
• MIDI input — connect a keyboard and answer with the instrument you know.
• Multiple sound sources powered by a SoundFont engine — piano, strings, sine waves, and more.
• CSV export and import — your data, in a format you can keep forever.

PRIVATE BY DEFAULT

Peach runs entirely on your device. No account, no sign-up, no analytics, no tracking. Your training data never leaves your iPhone, iPad, or Mac unless you export it yourself.

ONE APP, EVERY DEVICE

A single universal binary for iPhone, iPad, and Mac — native SwiftUI on every platform, not a stretched phone app. Practice on your phone in line, then check your profile on the Mac you have open.

WHO IT IS FOR

• Singers working on intonation and interval accuracy
• String, woodwind, and brass players refining pitch in tricky registers
• Anyone with the patience to get a little better, every day

Peach is a personal practice tool, not a test. Pick a discipline, do thirty seconds of practice, and put the phone away. Your ears do the rest.
```

Length: 2,515

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
Schärfere Ohren. Mehr Musikalität. Peach trainiert deine Wahrnehmung von Tonhöhe und Rhythmus, damit das, was du hörst, auch das ist, was du spielst — sauber und im richtigen Moment.

Peach ist eine fokussierte Gehörbildungs-App für Sängerinnen, Sänger und Instrumentalisten. Die App baut ein persönliches Profil deiner Wahrnehmung auf und nimmt leise genau die Stellen ins Visier, an denen du noch schwächer bist. Keine Punkte, keine Level, keine Streaks — jede kurze Übungsrunde macht dich einfach ein bisschen schärfer.

SECHS ÜBUNGSDISZIPLINEN

• Tonhöhe vergleichen — Zwei Töne erklingen; du entscheidest, welcher höher ist.
• Tonhöhe treffen — Stelle einen Ton mit dem Schieberegler so ein, dass er den Referenzton trifft.
• Intervalle vergleichen — Höre ein Intervall und beurteile, ob es sauber ist.
• Intervalle treffen — Stelle den zweiten Ton so ein, dass das Zielintervall entsteht.
• Timing vergleichen — Entscheide, ob ein Ton zu früh oder zu spät kommt.
• Lücke füllen — Tippe den fehlenden Schlag im richtigen Moment.

ADAPTIV VON GRUND AUF

Peach beobachtet, wie du antwortest, und passt den Schwierigkeitsgrad für dich an. Wird deine Unterscheidung feiner, werden die Cent- und Millisekundenabstände kleiner. Die Rhythmus-Übungen verfolgen deine Genauigkeit pro Tempo und behandeln zu früh und zu spät getrennt.

DEIN WAHRNEHMUNGSPROFIL

Auf dem Profil-Screen siehst du, wie dein Gehör über die Klaviatur und über die Tempi verteilt ist. Trends, Statistiken und ein Mini-Verlauf je Disziplin zeigen dir, ob deine Ohren schärfer werden.

GEMACHT FÜR ECHTE MUSIKER

• Gleichstufige Stimmung (12-TET) und reine Stimmung — trainiere in dem System, in dem du tatsächlich spielst.
• MIDI-Eingang — verbinde ein Keyboard und antworte mit dem Instrument, das du kennst.
• Mehrere Klangquellen über eine SoundFont-Engine — Klavier, Streicher, Sinus und mehr.
• CSV-Export und -Import — deine Daten, in einem Format, das dir lange erhalten bleibt.

VON HAUS AUS PRIVAT

Peach läuft vollständig auf deinem Gerät. Kein Konto, keine Registrierung, keine Analytik, kein Tracking. Deine Übungsdaten verlassen dein iPhone, iPad oder Mac nicht — es sei denn, du exportierst sie selbst.

EINE APP, ALLE GERÄTE

Eine einzige universelle Binary für iPhone, iPad und Mac — natives SwiftUI auf jeder Plattform, keine vergrößerte Handy-App. Übe in der Schlange am Telefon, schau danach auf dem geöffneten Mac in dein Profil.

FÜR WEN PEACH IST

• Sängerinnen und Sänger, die an Intonation und Intervallsicherheit arbeiten
• Streicher, Holz- und Blechbläser, die Tonhöhen in heiklen Lagen verfeinern
• Alle, die die Geduld haben, jeden Tag ein bisschen besser zu werden

Peach ist ein persönliches Übungswerkzeug, kein Test. Wähle eine Disziplin, übe dreißig Sekunden lang und steck das Telefon weg. Den Rest erledigen deine Ohren.
```

Length: 2,825

---

## Notes for Upload

- The character counts above were measured against the raw text inside the code fences. Re-check after any edits.
- Apple expects keywords as a single comma-separated string (no spaces between terms maximises the term budget).
- Apple already indexes the app name (`Peach`) and subtitle words for search; those terms are intentionally excluded from the keyword list.
- The German keyword list intentionally includes alternate instrument terms (`geige`, `bratsche`) alongside `violine`/`viola`-style searches; common Apple Music search queries skew colloquial.
- `Solfeggio` (DE) and `solfege` (EN) are spelled per the most-searched form on the App Store.
