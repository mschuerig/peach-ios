# Story 39.1: App Icon Redesign — AI-Generated Peach Icon

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want the app to have a polished, professional icon that clearly conveys "peach" and "hearing/sound",
so that the app looks credible on the App Store and my home screen, and communicates its ear-training purpose at a glance.

## Acceptance Criteria

1. Given the icon design, when viewed, then it prominently features a recognizable peach fruit that does NOT resemble a human posterior
2. Given the icon design, when viewed, then it incorporates a visual element representing hearing or sound (e.g., sound waves, musical notation, frequency curves, ear-related imagery) integrated naturally with the peach
3. Given the icon design, when evaluated against Apple's iOS icon guidelines, then foreground layers have clearly defined edges (no soft/feathered edges), no baked-in shadows or specular highlights (system applies these via Liquid Glass), and artwork is 1024x1024px in sRGB or Display P3 color space
4. Given the icon at small sizes (40x40px), when viewed on a home screen, then the design remains recognizable and the key elements (peach + sound) are still distinguishable — primary content is centered away from corners
5. Given the icon on a home screen, when viewed in default, dark, clear, and tinted appearances, then it has sufficient contrast and visual presence across all system-generated variants
6. Given the final icon, when assembled in Icon Composer and added to the Xcode project as a `.icon` file, then it replaces the existing `AppIcon` asset catalog entry and the build succeeds with zero warnings
7. Given the AI image generation process, when creating the icon, then a well-crafted prompt is developed through iteration, and the selected AI tool and final prompt are documented for reproducibility
8. Given the layered icon design, when assembled in Icon Composer, then the icon has at least a background layer (solid color or gradient) and one foreground layer group (peach + sound elements), producing a Liquid Glass effect with depth and vitality

## Tasks / Subtasks

- [ ] Task 1: Research and select the best AI image generation tool (AC: #7)
  - [ ] Evaluate candidate tools for icon-quality output: Midjourney, DALL-E 3, Stable Diffusion (with icon-focused models), Ideogram, Adobe Firefly
  - [ ] Consider: ability to produce clean vector-like graphics, control over composition, avoidance of photorealism artifacts, suitability for small-size legibility
  - [ ] Select one tool and document the rationale

- [ ] Task 2: Develop and iterate on the AI prompt (AC: #1, #2, #4, #7)
  - [ ] Draft an initial prompt incorporating all design requirements (see Dev Notes for prompt engineering guidance)
  - [ ] Key constraint: generate foreground elements only on a transparent background — Icon Composer handles the background separately
  - [ ] Generate first batch of candidates (3–5 variations)
  - [ ] Evaluate candidates against ACs #1, #2, #4 — iterate on prompt wording to fix issues
  - [ ] Repeat until a satisfactory result is achieved
  - [ ] Document the final prompt and all significant iterations

- [ ] Task 3: Post-process foreground artwork for Icon Composer (AC: #3, #8)
  - [ ] Ensure output is 1024x1024px (PNG or preferably SVG for scalability)
  - [ ] Remove any baked-in shadows, blurs, or specular highlights — system applies these via Liquid Glass
  - [ ] Ensure clearly defined edges on all foreground shapes (no soft/feathered edges)
  - [ ] Keep primary content centered (corners get clipped by the squircle mask)
  - [ ] If using raster (PNG): verify sRGB or Display P3 color space
  - [ ] Consider splitting into multiple foreground layers for depth (e.g., peach body as one layer, sound waves as another)

- [ ] Task 4: Assemble icon in Icon Composer (AC: #5, #6, #8) — user performs this
  - [ ] Open Icon Composer (Xcode > Open Developer Tool > Icon Composer)
  - [ ] Create new `.icon` file named `AppIcon`
  - [ ] Set platform to iOS Only (Document button > uncheck watchOS)
  - [ ] Set background: choose a solid color or top-to-bottom gradient (warm peach tones) via the Fill inspector
  - [ ] Import foreground layer(s): drag SVG/PNG files into the sidebar
  - [ ] Organize layers into groups (max 4 groups, back-to-front in z-plane)
  - [ ] Adjust Liquid Glass settings: Specular, Blur, Translucency, Shadow per layer/group
  - [ ] Vary opacity on foreground layers to increase depth and liveliness
  - [ ] Preview all appearances: Default, Dark, Mono (clear + tinted auto-generated)
  - [ ] Preview at multiple sizes (1024pt down to 40pt) to verify legibility
  - [ ] Save the `.icon` file

- [ ] Task 5: Add Icon Composer file to Xcode project (AC: #6)
  - [ ] Drag `AppIcon.icon` from Finder into the Xcode Project navigator (target folder)
  - [ ] In target > General > App Icons and Launch Screen, verify "App Icon" field matches `AppIcon` (no extension)
  - [ ] Note: the `.icon` file replaces the existing `AppIcon` asset catalog entry automatically
  - [ ] Build the project: `bin/build.sh`
  - [ ] Run the full test suite: `bin/test.sh`
  - [ ] Verify zero regressions and zero asset catalog warnings

- [ ] Task 6: Visual verification (AC: #4, #5, #6)
  - [ ] Run app on iOS Simulator, verify icon on home screen
  - [ ] Test icon in default, dark, and tinted appearances (Settings > Appearance)
  - [ ] Verify icon in Settings and Spotlight
  - [ ] Visually confirm small-size legibility at multiple preview sizes

## Dev Notes

### Previous Attempt Learnings (Story 7.5)

The current icon was generated via Claude Desktop's image generation. Key issues:
- **Posterior resemblance:** The peach shape, especially with the cleft/crease, reads as a butt. The new design must avoid this — consider showing the peach from a 3/4 angle, with the stem/leaf prominently visible, or using a more stylized/geometric peach shape.
- **Transparent background:** The current icon has a transparent background, violating Apple's edge-to-edge requirement. The new icon MUST fill the entire square with color.
- **Overly detailed for small sizes:** The ear and waveform details become muddy at 40x40px. Simpler, bolder shapes are needed.
- **Claude and ChatGPT limitations:** Both struggled to produce clean, icon-quality graphics. The user observed that neither is well-suited for this task. A dedicated image generation tool (Midjourney, Ideogram, etc.) or more carefully engineered prompts are needed.

### AI Image Generation Tool Selection Guidance

**User preference: free, non-subscription tools only.** No paid tiers or monthly subscriptions.

**Recommended free candidates (as of March 2026):**

| Tool | Free tier | Strengths | Weaknesses |
|------|-----------|-----------|------------|
| **Ideogram** (ideogram.ai) | Yes, generous free tier | Excellent at logos and graphic design, clean style, good composition control | May have daily generation limits |
| **Microsoft Designer** (designer.microsoft.com) | Yes, with Microsoft account | DALL-E 3 powered, good instruction following, square output | Can produce overly "AI-looking" results |
| **Leonardo.ai** | Yes, 150 tokens/day | Multiple models including icon-suitable styles, fine control | Token-limited; best results may require specific model selection |
| **Stable Diffusion** (local via ComfyUI/AUTOMATIC1111) | Fully free, open source | Full control, unlimited generations, reproducible, icon-focused LoRA models available | Requires local setup (Python, GPU recommended), learning curve |
| **Recraft** (recraft.ai) | Yes, free tier | Specifically designed for icons/illustrations, vector output option | Newer tool, generation limits |
| **Bing Image Creator** (bing.com/images/create) | Yes, with Microsoft account | DALL-E 3 powered, no signup beyond MS account | Less control over style parameters |

**Not recommended (paid/subscription):**
- Midjourney (paid only), Adobe Firefly (limited free, subscription for full), ChatGPT Plus (subscription for DALL-E 3 quality)

**Key selection criteria for app icons:**
- Ability to produce flat/semi-flat illustration style (not photorealistic)
- Clean edges and shapes that scale down well
- Good control over composition and element placement
- Transparent or solid-color background output (for easy separation)

### Prompt Engineering Guidance

**Core elements to include in any prompt:**

```
Subject: A stylized peach fruit (3/4 view, stem and leaf visible at top)
Sound element: [sound waves / musical waveform / frequency visualization]
  emanating from or integrated with the peach
Style: Flat/semi-flat digital illustration, clean vector-like shapes,
  bold colors, minimal detail, clearly defined hard edges
Format: Square 1024x1024 icon artwork on TRANSPARENT background
  (background will be added separately in Icon Composer)
Color palette: Warm peach/coral/orange tones for the fruit, accent
  color for sound elements (teal, green, or gold)
Constraints: Simple enough to be recognizable at very small sizes,
  NO photorealism, NO human body parts, NO shadows or glows
  (system adds these), NO background color, centered composition
  (corners will be clipped by rounded-rect mask)
```

**Important for Liquid Glass workflow:**
The AI should generate **foreground elements only** on a transparent background. The background color/gradient is set separately in Icon Composer. This means the prompt should NOT ask for a filled background — instead request transparent/no background.

**Fallback if AI tool can't do transparent backgrounds:**
Many AI image generators default to solid backgrounds. If transparent output isn't available: generate on a uniform solid color (e.g., bright green or magenta) and remove the background in post-processing using Preview, Photoshop, or an online background removal tool. Alternatively, generate on white and manually separate the foreground elements.

**Anti-posterior strategies:**
- Specify "3/4 angle" or "side view" to avoid the symmetrical cleft
- Emphasize "stem and leaf prominently visible at top" — this is the strongest visual cue that it's a fruit
- Use "stylized" or "geometric" to steer away from anatomical realism
- Consider a slight tilt or asymmetry
- Include a small leaf or twig detail that breaks the symmetry

**Prompt iteration strategy:**
1. Start with a descriptive prompt covering all requirements
2. If the peach looks like a posterior → add "fruit, not anatomy" negative prompt, adjust angle
3. If too detailed → add "minimal", "simple shapes", "flat design"
4. If sound element is unclear → try different representations (concentric arcs vs. sine wave vs. musical notes)
5. If edges don't fill the canvas → add "fills entire square", "no margins", "edge-to-edge"

### Icon Composer (Required Workflow)

Apple's Icon Composer is the recommended tool for creating iOS icons with Liquid Glass effects. The `.icon` file format replaces the traditional asset catalog `AppIcon.appiconset` approach.

**How it works:**
- **Launch:** Xcode > Open Developer Tool > Icon Composer (also available as standalone download)
- **Structure:** Layers organized into up to 4 groups, rendered back-to-front in the z-plane
- **Background:** Set via Icon Composer's own Fill inspector (Solid or Gradient) — no need to import a background image
- **Foreground:** Import SVG (preferred) or PNG layers; Icon Composer auto-applies Liquid Glass material
- **Liquid Glass settings per layer/group:** Mode (Individual/Combined), Specular, Blur, Translucency, Shadow
- **Appearances:** Preview Default, Dark, Mono; system auto-generates Clear and Tinted variants
- **Output:** `.icon` file added directly to Xcode project; replaces any existing `AppIcon` asset catalog

**Suggested layer structure for Peach icon:**
- **Background group (bottom):** Solid warm peach/coral gradient (set in Icon Composer, not imported)
- **Foreground group 1:** Peach body shape (the fruit)
- **Foreground group 2:** Sound wave / hearing element (on top, for parallax depth)
- **Optional foreground layer:** Stem + leaf detail

**Key Icon Composer tips from Apple docs:**
- Prefer SVG for foreground layers (scales gracefully at all sizes)
- Clearly defined edges on foreground shapes — avoid soft/feathered edges
- Do NOT bake in shadows, blurs, or specular highlights — system applies these dynamically
- Remove background colors from imported artwork — Icon Composer handles the background
- Vary opacity in foreground layers to increase sense of depth
- Subtle top-to-bottom, light-to-dark gradients respond well to system lighting effects
- Use filled, overlapping shapes for depth

**The user is willing to perform tasks in Icon Composer** (importing layers, adjusting settings, previewing).

### Apple App Icon Requirements (iOS) — From HIG June 2025

**Specifications:**
- **Layout:** Square, 1024x1024px
- **Masking:** System applies rounded rectangle (squircle) — provide unmasked square layers
- **Style:** Layered (Liquid Glass) — background + foreground layers
- **Appearances:** Default, dark, clear light, clear dark, tinted light, tinted dark (auto-generated from your design)
- **Color spaces:** sRGB, Gray Gamma 2.2, Display P3 (wide-gamut)

**Design principles (from Apple HIG):**
- **Embrace simplicity** — minimal number of shapes; prefer simple background (solid/gradient)
- **Prefer illustrations over photos** — photos don't work well at small sizes or across appearances
- **Filled, overlapping shapes** paired with transparency and blurring give depth
- **Keep primary content centered** — corners get clipped by the mask
- **No baked visual effects** — let the system handle specular highlights, drop shadows, blurs, glows
- **Text only if essential** — doesn't support accessibility/localization, too small to read at icon sizes
- **Don't replicate Apple hardware or UI components**
- **Avoid black backgrounds** — lighten so icon doesn't blend into display background
- **Design dark/tinted icons that feel at home** — dark icons are more subdued; clear and tinted even more so
- **Keep features consistent across appearances** — don't swap elements between variants

### Technical Requirements

- Foreground artwork: 1024x1024px SVG (preferred) or PNG, on transparent background
- Background: set in Icon Composer (solid color or gradient — no imported image needed)
- Output: `AppIcon.icon` file (Icon Composer format)
- File added to the Xcode project's Peach target (drag into Project navigator; Xcode places it alongside the target's sources)
- Target > General > App Icons and Launch Screen > "App Icon" must match `AppIcon`
- The `.icon` file replaces the existing `AppIcon` asset catalog automatically
- No Swift code changes required
- No new dependencies

### What NOT To Change

- Do NOT modify any Swift source files
- Do NOT modify the project structure
- Do NOT add any new dependencies
- The existing `AppIcon.appiconset` will be superseded by the `.icon` file automatically

### Project Structure Notes

- New file: `AppIcon.icon` (Icon Composer file) added to Xcode project
- The existing `Peach/Resources/Assets.xcassets/AppIcon.appiconset/` is superseded — Xcode uses the `.icon` file instead
- The old `AppIcon.appiconset` can optionally be removed (Xcode auto-generates a compatible fallback from the `.icon` file for older OS versions)
- No structural changes beyond the icon file

### References

- [Source: docs/implementation-artifacts/7-5-app-icon-design-and-implementation.md] — Previous icon story, learnings, and color palette
- [Source: Apple HIG - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) — Design guidelines
- [Source: Apple - Icon Composer](https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer) — Layered icon creation tool
- [Source: Peach/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json] — Current asset catalog config

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

### Completion Notes List

- Task 1 (tool selection): ChatGPT/DALL-E selected. Recraft was initially preferred for SVG output but has restrictive free-tier licensing (no commercial use). ChatGPT grants full ownership even on free tier.
- Task 2 (prompt iteration): Extensive iteration attempted. Key findings:
  - Symmetrical peach shape always reads as posterior — side/3/4 view fixes this
  - Sound waves emanating from a peach risk looking like flatulence
  - "Peach-ear" concept (ear shaped/colored like a peach with stem+leaves) is the most promising direction
  - Cross-section peach with ear as pit looked like a strawberry at icon size
  - Separate sound wave SVG layer looked moth-eaten under Liquid Glass (stroked paths disintegrate; filled crescents too small to read)
  - DALL-E struggles with: transparent backgrounds, mirroring/facing direction, incremental edits, separating foreground from fruit concept
  - Best result so far: a standalone ear colored in peach tones with stem and two leaves (cartoon/sticker style) — concept works but execution needs refinement
- Story paused at ready-for-dev — no final icon selected yet

### Change Log

### File List
