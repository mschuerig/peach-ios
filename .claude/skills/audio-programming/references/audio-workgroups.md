# Audio Workgroups

**Advanced topic.** Most audio code does not need workgroups. Reach for them only when measurements show one render thread is the bottleneck and you need to parallelize across CPU cores.

## What an audio workgroup is

An audio workgroup is an OS scheduling primitive that groups threads working cooperatively toward the same audio render deadline. The kernel uses workgroup membership to coordinate CPU allocation, deadline-aware priority, and core selection (P-cores vs E-cores on Apple Silicon) so all members can finish their share of a render cycle before the buffer is due.

Joining a workgroup tells the OS "this thread participates in the same real-time deadline as the audio device thread," which:

- Protects it from preemption by ordinary high-priority threads.
- Helps the scheduler pick the right core cluster.
- Coordinates wake-up across worker threads.

The canonical WWDC talk is **"Meet Audio Workgroups," WWDC20 Session 10224**, presented by Doug Wyatt. Workgroups were introduced in **macOS 11 / iOS 14** (fall 2020). The `os_workgroup_t` type lives in `<os/workgroup.h>`.

## API surface

### Acquiring a workgroup

- **`AUAudioUnit.osWorkgroup`** — the workgroup parented to the audio render context. For an engine, reach via:
  ```swift
  let wg = engine.outputNode.auAudioUnit.osWorkgroup
  ```
  Only valid once render resources are allocated. Observe changes via `AURenderContextObserver`.
- **HAL / `AURemoteIO`** — on macOS, the device's workgroup from output unit properties; on iOS, via `AURemoteIO`.

### Joining and leaving

Call from the worker thread itself, once each:

```c
os_workgroup_join_token_s tok;
int rc = os_workgroup_join(workgroup, &tok);
if (rc == 0) {
    // ... do work in workgroup membership ...
    os_workgroup_leave(workgroup, &tok);
}
```

### Custom workgroups for asynchronous deadlines

When your work has a different period than the audio device (e.g., a granular engine generating buffers ahead of time):

```c
os_workgroup_t wg = AudioWorkIntervalCreate("synthesis", clockID, attrs);
// Master thread per cycle:
os_workgroup_interval_start(wg, start, deadline, NULL);
// ... parallel work ...
os_workgroup_interval_finish(wg, NULL);
```

Use `mach_timebase_info` for the clock.

### Sizing

```c
int n = os_workgroup_max_parallel_threads(wg, NULL);
```

The recommended fan-out — don't exceed it.

## When to use workgroups

Use them when you spawn **additional real-time threads** that share the render deadline:

- **Parallel DSP fan-out**: splitting a heavy convolution, FFT block, or per-voice polyphonic synthesis across cores so the total work fits in one render quantum.
- **Auxiliary render-rate work in an AUv3 plugin**: the host's render thread is the principal; your worker threads join via the `AURenderContextObserver` block that delivers the host's `os_workgroup`.
- **Asynchronous-but-periodic work** with a different period than the device (e.g., a granular engine generating buffers ahead of the audio I/O cycle): create your own workgroup with `AudioWorkIntervalCreate`.

## When NOT to use workgroups

- **One-shot or sporadic non-realtime work** (file I/O, preset loading, UI updates) — use `Task`, actors, `DispatchQueue`, `OperationQueue`.
- **App-level concurrency** — Swift Concurrency is the right tool.
- **The render thread itself in a standard AVAudioEngine / AUv3 setup** — the host already manages its membership. Joining redundantly is wrong.
- **General-purpose worker threads** that may block, allocate, or call into the Swift runtime. Joining a workgroup imposes the four RT rules on the thread; if you can't honor them, don't join.

## Rules and pitfalls

- **The four RT rules apply to every joined thread.** No locks that can wait on non-RT threads, no allocation, no syscalls that may block, no priority inversions. Joining a workgroup does not make a thread real-time-safe; it only opts it into coordinated scheduling.
- **Finish within the interval.** Missing the deadline degrades the scheduler's model and can cause glitches across the *whole* workgroup, not just your thread.
- **Pair join / leave on the same thread.** The join token is per-thread; leaking it leaves stale members.
- **Don't join general-purpose worker threads.** Doing so causes priority inversions when those threads block on non-RT operations.
- **Observe context changes**: the host's workgroup can change (engine reconfig, route change). Re-join via `AURenderContextObserver`; `os_workgroup_join` may return `EINVAL` if attempted at the wrong time. This is a well-known JUCE pitfall — see JUCE forum 54240.
- **visionOS** has additional, stricter expectations for compositor-coupled audio; verify per-platform.

## Common ways to use it

### Joining auxiliary worker threads in an AUv3

```swift
class MyAU: AUAudioUnit {
    override var renderContextObserver: AURenderContextObserver? {
        return { renderContext in
            // Called when the host's render context changes
            // Workers should re-join the new workgroup
            self.scheduleWorkersJoin(renderContext.pointee.workgroup)
        }
    }
}
```

### Parallel polyphonic synthesis

Master render thread receives the request; dispatches per-voice work to N workers (each pinned to a P-core ideally); waits for all to complete; mixes. Cost: synchronization overhead. Worth it only when single-thread render exceeds the budget.

## Authoritative sources

- WWDC20 Session 10224 — "Meet Audio Workgroups" (Doug Wyatt) — https://developer.apple.com/videos/play/wwdc2020/10224/
- Workgroup Management (Audio Toolbox) — https://developer.apple.com/documentation/audiotoolbox/workgroup-management
- Understanding Audio Workgroups — https://developer.apple.com/documentation/audiotoolbox/workgroup_management/understanding_audio_workgroups/
- Adding Parallel Real-Time Threads — https://developer.apple.com/documentation/audiotoolbox/workgroup_management/adding_parallel_real-time_threads_to_audio_workgroups
- Adding AU Auxiliary RT Threads — https://developer.apple.com/documentation/audiotoolbox/workgroup_management/adding_audio_unit_auxiliary_real-time_threads_to_audio_workgroups
- Adding Asynchronous RT Threads — https://developer.apple.com/documentation/audiotoolbox/workgroup_management/adding_asynchronous_real-time_threads_to_audio_workgroups
- os Workgroups API index — https://developer.apple.com/documentation/os/workgroups
- AudioUnitRenderContext.workgroup — https://developer.apple.com/documentation/audiotoolbox/audiounitrendercontext/workgroup
- Timur Doumler ADC talks on real-time threads
- JUCE forum thread 54240 — `os_workgroup_join` returning `EINVAL` outside an active render context — https://forum.juce.com/t/os-workgroup-join-consistently-returns-einval-cant-join-audio-workgroup/54240/17

## Verification status

- WWDC20 Session 10224 title and presenter confirmed via WebFetch.
- `os_workgroup` availability: macOS 11 / iOS 14 (introduced WWDC20). Earlier reports of "iOS 16.4" are wrong.
- Reference documentation pages return only titles via WebFetch (JS-rendered); their body text was not directly fetched, so re-verify specifics against the headers in your installed SDK.
