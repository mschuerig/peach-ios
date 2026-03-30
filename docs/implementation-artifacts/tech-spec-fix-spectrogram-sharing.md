---
status: done
slug: fix-spectrogram-sharing
---

# Fix Spectrogram Sharing on Profile Screen

## Problem

`RhythmProfileCardExportView` rendered via `ImageRenderer` produces a broken/empty image because:
1. Missing `perceptualProfile` environment — `RhythmSpectrogramView` gets an empty default profile
2. `.regularMaterial` background — requires window compositing context, renders transparent in `ImageRenderer`

## Fix

- Inject `perceptualProfile` into the export view in `renderShareImage()`
- Replace `.regularMaterial` with `Color.platformBackground` in the export view
