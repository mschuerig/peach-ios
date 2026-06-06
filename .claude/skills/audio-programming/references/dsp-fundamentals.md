# DSP Fundamentals for App Developers

Target audience: app developers who are not DSP engineers, but who write or maintain code that calls audio APIs, processes buffers, or makes audio-rate decisions. The goal is to make you literate enough to read DSP code, recognize wrong choices, and know when to escalate to a real DSP engineer.

## Sampling and Nyquist

Audio is sampled at a fixed rate. The **Nyquist-Shannon theorem** says perfect reconstruction is possible only if the sample rate is at least twice the highest frequency present.

- At 48 kHz, the Nyquist frequency is 24 kHz; anything above must be filtered out before sampling or it **aliases** (folds back as audible garbage).
- This is why ADCs, resamplers, and oscillators all need anti-aliasing.
- Smith, *The Scientist and Engineer's Guide to DSP*, ch. 3 (dspguide.com).

## PCM representations

| Format | Range | Dynamic range | Headroom | Use |
|---|---|---|---|---|
| Int16 | ±32767 | ~96 dB | none above 0 dBFS | Files, networks, legacy I/O |
| Int24 / Int32 | larger | ~144 / 192 dB | none above 0 dBFS | Pro audio interfaces, files |
| Float32 | ±∞ (nominal ±1.0) | ~144 dB at unity | yes (clipping only at DAC) | Core Audio internal default |

Apple processing graphs are Float32 by default. Values above 1.0 are legal in-flight; only the final DAC stage clips.

**Bit depth** = dynamic range. **Sample rate** = bandwidth.

## Sample rates — why 44.1 and 48 both exist

- **44.1 kHz** — CD-DA legacy; chosen so PCM fit in NTSC/PAL video frames on Sony PCM-1600 recorders.
- **48 kHz** — broadcast/film/video standard; Apple's default device rate on iOS.
- **96 / 192 kHz** — oversampling for nonlinear processing (saturation, wavetables), tracking, or to push aliasing artifacts further from the audible band. Rarely needed for plain playback.

Resampling 44.1 ↔ 48 is non-integer and requires a polyphase filter. Cheap resamplers introduce aliasing or imaging. Use `AVAudioConverter` or `AVAudioMixerNode`, not hand-rolled linear interpolation.

## Channels, interleaving, buffer layout

- **Interleaved**: `L R L R L R …` — common in files and hardware I/O.
- **Non-interleaved / planar**: `L L L … | R R R …` — what Core Audio render callbacks and most DSP code prefer (each channel is contiguous Float32, Accelerate can vectorize).

`AVAudioPCMBuffer.format` (an `AVAudioFormat`) tells you sample rate, channel count, common format (Float32 / Int16 / …), and `isInterleaved`. **Check it.** Mismatch is the #1 cause of silence, distortion, and crashes.

## Latency math

```
latency_ms = frames / sample_rate × 1000
```

- 256 frames @ 48 kHz = 5.33 ms
- 1024 frames @ 48 kHz = 21.3 ms

Round-trip = input buffer + processing + output buffer + driver/HW. iOS targets ~5 ms achievable; <3 ms is hard. Larger buffers = more CPU headroom, more latency.

`AVAudioSession.setPreferredIOBufferDuration(_:)` is a request, not a guarantee.

## Block processing

Audio APIs hand you N frames at a time. All DSP state (filter delays, phase accumulators, envelopes) must persist *across* blocks. Per-sample inner loops should be tight, branch-free, allocation-free, lock-free.

## Time vs frequency domain

Most processing happens sample-by-sample in the **time domain** (filters, gain, mixing). For spectral work — pitch detection, FFT-based EQ, convolution reverb, vocoders — you transform to the **frequency domain** via FFT.

Accelerate's `vDSP_fft_zrip` family is the canonical Apple FFT; use it. Don't write your own (apple.com/documentation/accelerate/fast_fourier_transforms).

FFTs require:
- Power-of-two sizes
- Windowing (Hann, Hamming, etc.) to reduce spectral leakage
- Overlap-add when reconstructing time-domain output (typically 50%–75% overlap)

## Decibels, gain staging, clipping

`dBFS = 20·log10(|sample|)`. 0 dBFS = ±1.0. Doubling amplitude = +6 dB. Cutting in half = −6 dB.

- **Headroom**: keep peaks ≤ −6 dBFS internally so summing doesn't clip.
- **Clipping**: any sample > ±1.0 at the DAC = hard distortion. Float32 buses can transiently exceed 1.0 — only the final output stage matters, but cheap soft-clip or limiter at master is hygiene.
- **Gain staging**: apply gain where it makes sense (post-filter, pre-saturation). Avoid unity-gain feedback loops.

## DSP building blocks — recognize, don't reinvent

- **Oscillator** — sine / saw / square. Naive saws and squares alias; production code uses BLEP, BLIT, or wavetables.
- **Biquad** — 2-pole 2-zero IIR filter; the universal building block for EQ, low/high/bandpass/notch/shelf. Cookbook coefficients: RBJ (https://www.w3.org/TR/audio-eq-cookbook/).
- **IIR vs FIR** — IIR (recursive, biquads) is cheap, has feedback (can go unstable), nonlinear phase. FIR (no feedback) is stable, linear phase possible, expensive for sharp cutoffs.
- **Convolution** — multiply in frequency domain = convolve in time domain. Used for IR reverb, cabinet sims. Use `vDSP_conv` or FFT-based partitioned convolution.
- **Envelope / ADSR** — Attack/Decay/Sustain/Release shape applied to amplitude or filter cutoff. Per-sample or per-block ramp.
- **LFO** — low-frequency oscillator (<20 Hz) modulating other parameters (vibrato, tremolo, chorus).
- **Resampler** — needs polyphase / sinc-based filtering for quality; linear interpolation produces audible aliasing.

For canonical implementations: Pirkle's *Designing Audio Effect Plug-Ins in C++*, Zölzer's *DAFX*. For theory: Reiss & McPherson's *Audio Effects*. For breadth: Roads' *Computer Music Tutorial*. For battle-tested snippets: musicdsp.org archive.

## Dither, anti-aliasing, oversampling

- **Dither** — tiny random noise added before bit-depth reduction (Float32 → Int16) to decorrelate quantization error. Without it, low-level signals get distorted, not just noisy.
- **Anti-aliasing filter** — lowpass before downsampling or after a nonlinear stage to remove energy above Nyquist.
- **Oversampling** — process at 2× / 4× rate through a nonlinearity, then downsample. Pushes aliasing artifacts out of the audible band.

## Numerical hazards

- **DC offset** — non-zero mean in the signal. Wastes headroom, can thump speakers. Block with a high-pass at ~5–20 Hz.
- **NaN / Inf** — one bad sample (divide by zero, log of 0, runaway IIR) poisons every downstream calculation. Filters latch into silence or screaming. Sanity-check inputs to nonlinearities.
- **Denormals** — subnormal floats near zero. On Intel they cause ~100× CPU stalls; common in IIR tails fading to silence.
  - Apple Silicon largely immune.
  - Mitigations: flush-to-zero / denormals-are-zero (FTZ/DAZ), or inject tiny noise/offset.

## Accelerate framework

Apple's vectorized math. SIMD-optimized, free, the right answer for batch work on Float32 arrays.

- **vDSP** — vector arithmetic, FFTs, biquads (`vDSP_biquad`), convolution, windowing, conversion.
  https://developer.apple.com/documentation/accelerate/vdsp
- **vForce** — vectorized transcendentals (`vvsinf`, `vvexpf`, `vvlogf`).
- **BNNS** — neural network primitives; relevant for ML-based audio.

Prefer vDSP over per-sample Swift loops for anything over ~32 samples.

## When to escalate

If a PR's audio code:

- Allocates inside a render block
- Ignores `AVAudioFormat`
- Hand-rolls an FFT or resampler
- Divides without bounds-checking
- Assumes 44.1 kHz everywhere

…push back.

When the math gets real (filter design, psychoacoustics, custom DSP algorithms, novel synthesis), get a DSP engineer. This skill makes you literate, not expert.

## Authoritative sources

- Steven W. Smith — *The Scientist and Engineer's Guide to Digital Signal Processing* (free) — https://www.dspguide.com/
- Will Pirkle — *Designing Audio Effect Plug-Ins in C++* / *Designing Software Synthesizer Plug-Ins in C++*
- Udo Zölzer (ed.) — *DAFX: Digital Audio Effects*
- Joshua D. Reiss & Andrew McPherson — *Audio Effects: Theory, Implementation and Application*
- Curtis Roads — *The Computer Music Tutorial*
- Robert Bristow-Johnson (RBJ) — Cookbook formulae for audio EQ biquad filter coefficients — https://www.w3.org/TR/audio-eq-cookbook/
- Music DSP archive — https://www.musicdsp.org/
- Apple Accelerate — https://developer.apple.com/documentation/accelerate
