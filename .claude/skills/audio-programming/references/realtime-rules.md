# The Four Rules of the Render Thread

The audio render thread runs at real-time priority on a system-owned pthread (time-constraint policy). The OS schedules it deterministically against a deadline tied to the I/O buffer size and sample rate. Miss the deadline and the output buffer goes out empty — an audible glitch or dropout. Cause a priority inversion and the audio output can stall entirely.

The four rules below are operational constraints, not aesthetic preferences. They are nearly universally agreed across Bencina, Doumler, Tyson, Pirkle, Falco, JUCE conventions, and Apple's own `AVAudioSourceNode` documentation.

## Rule 1 — No Allocation or Free

> The memory allocator may use algorithms that take unpredictable amounts of time to decide how to allocate a block. The recommended approach is to pre-allocate all data and only perform dynamic allocation in a non-real-time thread.

Forbidden on the render thread:

- `malloc` / `free` / `calloc` / `realloc`
- C++ `new` / `delete`
- Swift class allocation (calls `swift_allocObject` which may trigger malloc)
- Implicit Swift heap allocations: `Array.append` past capacity, `Dictionary` insertion that resizes, `String` construction, boxing of `Any`, large-payload closure capture, `print` formatting, `defer` (synthesizes a closure)
- Obj-C `[NSObject alloc]` / `[NSObject new]` and any path that grows an autorelease pool
- `os_log` with format strings that allocate (most cases that pass dynamic args)

Pre-allocation strategies:

- Reserve `Array` capacity at construction. Never grow during render.
- Use `UnsafeMutableBufferPointer<T>` / `UnsafeMutablePointer<T>` over `Array` for hot paths.
- Use stack-allocated `withUnsafeTemporaryAllocation(of:capacity:_:)` for scratch buffers inside a render block (Swift 5.7+). This stays on the stack and does not allocate.
- For object-like state, pre-create instances in a pool; the render thread acquires and releases pool slots, never alloc/free.

## Rule 2 — No Blocking Lock

> If you have a stream of objects flowing from one thread to the other, such as MIDI messages, you can use a lock-free single-producer single-consumer FIFO. (Doumler)

Forbidden on the render thread:

- `NSLock`, `pthread_mutex_t`, `os_unfair_lock` (blocking acquisition; `try` variants with fallback are OK)
- `DispatchSemaphore`, `Mutex` (blocking acquisition)
- `DispatchQueue.sync` (it will block; never use from render)
- Anything that can block on the non-realtime side, because that's where priority inversion bites you

What is acceptable:

- `try_lock` / `os_unfair_lock_trylock` with a *defined fallback strategy* — use the previous value, drop the update, increment a diagnostics counter. Never spin.
- Pure atomic primitives (`Atomic<T>` in Swift 6+, `OSAtomic*`, `std::atomic`). Pure atomic ops are bounded-time.
- Lock-free SPSC FIFOs (TPCircularBuffer, JUCE `AbstractFifo`, hand-rolled ring buffer). Producer is non-realtime; consumer is the render thread.

Doumler's nuance: locks are not *categorically* forbidden. What is forbidden is blocking acquisition on the render thread. A `try_lock` with a graceful fallback is sometimes the *cheapest* correct pattern, particularly for parameter snapshots that change rarely.

## Rule 3 — No Obj-C or Swift Runtime That Can Lock or Allocate

This is the rule that catches people writing render blocks in Swift.

Forbidden (because each can lock or allocate internally):

- Method dispatch through Obj-C selectors (`[obj method]` in Swift via `@objc`)
- KVO observation firing
- Notification posting
- `Dictionary` and `Set` operations on non-trivially-typed keys (hashing may allocate)
- `String` interpolation; `String` comparisons that aren't pure ASCII via fast path
- ARC retain/release on classes whose dealloc may trigger nontrivial work; even routine retain/release contends `swift_retain`'s global table when many threads are involved
- `as?` downcasts that traverse the class hierarchy
- Reflection (`Mirror`)
- `os_log` with allocating arguments

What is acceptable in Swift on the render thread:

- Pure value-type operations on `Int`, `Float`, `Double`, fixed-size tuples, `SIMD*`, structs of those
- Pointer arithmetic via `UnsafeMutablePointer` / `UnsafeMutableBufferPointer`
- Atomic operations on `Atomic<Int>` etc. (Swift 6+)
- Calling C functions imported via `@_silgen_name` or a bridging header (the C function itself must be RT-safe)
- Stack-only allocation via `withUnsafeTemporaryAllocation`
- Pure-arithmetic `@inlinable` Swift functions, *if* you've verified the optimizer eliminates allocation (check SIL)

**The conservative rule:** if a Swift symbol could conceivably involve the Swift runtime, treat it as unsafe in a render block until you've inspected the SIL or asm to confirm otherwise.

Apple's `AVAudioSourceNode` docs say it directly:

> The code in the block must be realtime-safe. Don't make any blocking calls (including allocation, locks, file I/O, or Objective-C messaging) from within the render block.

Swift class messaging is no safer than Obj-C messaging.

## Rule 4 — No I/O

No file access, no disk reads, no network, no syscalls that may block. No `print`. No image loading, no `Bundle` lookup, no `URL` construction.

This includes things that *look* like memory access but aren't:

- Memory-mapped files where the page isn't resident yet — the read triggers a page fault that may go to disk
- Large pre-allocated buffers that have never been touched — they may sit in zero-pages that take real memory at first access; **touch them at construction** to fault them in
- Touching a `Data` object whose backing is mmapped (e.g., loaded via `Data(contentsOf:)` with `.alwaysMapped`)

When loading audio assets (soundfonts, IRs, samples): load and force-resident in setup, on a non-realtime thread, before the render thread touches them. `mlock` / `madvise` are options on systems that expose them.

## Swift Concurrency vs the Render Thread

There is no Swift Concurrency on the render thread.

- The render callback runs on a system-owned pthread. There is no Task there. There is no actor isolation. There is no continuation suspending and resuming.
- You cannot `await` in a render block. The block isn't an async function.
- You cannot reach an actor's isolated state from a render block. Even if you could compile it, the `await` to enter the actor would be a category error: the render thread cannot suspend and resume cooperatively without missing its deadline.
- `@MainActor` does not protect you on the render thread. It protects you *from* the render thread.
- A `Sendable` wrapper around a lock-free buffer is fine — purely a compile-time annotation. An `actor` wrapping render-thread state is not fine.

If you find yourself wanting to call into Swift Concurrency from a render block, you have a structural problem. Reformulate: the non-realtime side coordinates via async/await and hands the render thread a pre-prepared buffer or atomic snapshot.

## Auditing a Render Block

Checklist when reviewing a render block, source-node block, `AURenderBlock`, or `AUAudioUnit.internalRenderBlock`:

1. **Set breakpoints in malloc/free** and run the audio path. Real-time audio is one of the few places this is genuinely useful as a smoke test.
2. **Open the SIL output** (`swiftc -emit-sil`) for any Swift function on the path. `alloc_stack` is fine; `alloc_box`, `alloc_ref`, allocating `partial_apply`, retain/release of non-trivial types is suspect.
3. **Grep for retains in the assembly**: `swift_retain`, `swift_release`, `objc_msgSend`, `objc_retain`. Their presence on the hot path is a red flag.
4. **Inspect every function call site.** Does the called function take a lock internally? Allocate? Cross a thread? If it's a `@convention(c)` C function with a known implementation, document that. If it's a Swift function, you have to look.
5. **No closures captured by value of non-trivial types.** A closure that captures `self` (class) implies retain/release on entry and exit.
6. **No `defer`** in a render block. `defer` synthesizes a closure.
7. **No exception throwing.** Swift's `throw` allocates the error.
8. **Run with the Address Sanitizer** under audio load. Allocations sometimes only show up under contention.
9. **No `self` captured directly** in an AUv3 `internalRenderBlock` getter — capture an immutable pointer to a C++ struct / DSP kernel instead.

## Diagnosing a Glitch After the Fact

When a customer reports glitches you can't reproduce locally:

- Get a `sysdiagnose`. The audio framework logs `IOAudio2Device` and `AudioHAL` events including underrun counts.
- Xcode Instruments **Time Profiler** with "Record Waiting Threads" enabled surfaces the render thread waiting on a lock.
- The **Audio System Trace** Instrument captures every render cycle and shows deadline misses.
- Logged underruns at the `AUAudioUnit.maximumFramesToRender` boundary indicate the render thread missed its deadline.
- A reproducible glitch under specific conditions (e.g., "only when the network is busy") almost always points to a runtime service taking a contended lock — most often something allocating, logging, or talking to `os_unfair_lock` from both an autorelease pool drain and the render thread.

Detail on Instruments and `os_signpost` caveats: `performance-and-debugging.md`.

## Practical Swift Patterns

### Atomic flag for one-shot signal

```swift
let needsReset = Atomic<Bool>(false)

// Non-realtime context:
needsReset.store(true, ordering: .relaxed)

// Render thread:
if needsReset.exchange(false, ordering: .relaxed) {
    // do the reset work — pre-allocated, bounded time
}
```

Acceptable. But: see `inter-thread-patterns.md` for why an *isolated* atomic flag is dangerous when there is also an in-band event path going to the same consumer.

### SPSC ring buffer with `UnsafeMutableBufferPointer`

Pre-allocate at construction. Producer writes; reader reads. Use `Atomic<Int>` for head/tail indices. Don't reach for a generic Swift solution; analyzing the RT-safety of a generic container is much harder than of a hand-written buffer.

### Pool of pre-allocated state objects

```swift
struct Voice { /* trivial, no class members */ }
let voices = UnsafeMutableBufferPointer<Voice>.allocate(capacity: 32)
// Initialise voices at construction. Render thread reads/writes by index.
// No alloc/free on the render thread.
```

### Pre-touching pages

```swift
// At setup, on a non-realtime thread:
buffer.initialize(repeating: 0)  // forces all pages resident
```

A pre-allocated buffer that has never been written may be zero-filled-on-demand by the kernel. Touching every byte at setup forces the pages to be backed by real memory.

## When You Genuinely Need to Compute on the Render Thread

If you're writing DSP (filters, oscillators, granular, samplers), you *will* be computing in the render block. The four rules apply, but you can:

- Use SIMD (`SIMD2<Float>` etc.) — vectorised loads/stores with no allocation.
- Use `@inlinable` Swift functions that compile to straight-line code.
- Cache `sin`/`cos`/exp tables at setup.
- Use Accelerate (`vDSP_*`, `vForce`) — documented RT-safe entry points are vectorised and fast.

The boundary where you *cannot* trust Swift on the render thread is at any point that touches the Swift runtime: class allocation, dictionary insertion, string handling, exception throwing. Use C / C++ / Obj-C++ for the hot loop when in doubt; for AUv3 development this is the industry default.

For apps that mostly host Apple's Audio Units (samplers, effects) rather than writing their own DSP, render-block exposure is to: the MIDI-out block, the configuration-change observer, any `AVAudioSourceNode`/`SinkNode` blocks, and threads joined to the audio workgroup. The discipline applies there.

## Denormals

On Intel CPUs, subnormal floats (very small numbers near zero) trigger microcode paths that can be ~100× slower. Common cause: IIR filter tails decaying to silence.

Mitigations:
- Enable flush-to-zero and denormals-are-zero (FTZ/DAZ) at thread setup. On macOS:
  ```c
  #include <fenv.h>
  _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);   // x86 only
  ```
- On Apple Silicon, denormals are handled in hardware without the slowdown; the issue largely went away but don't rely on it for cross-architecture code.
- Inject tiny noise or DC offset into IIR tails to avoid the subnormal regime entirely.
