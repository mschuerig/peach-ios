/// View-local memoization: recomputes `value` only when `generation` changes.
///
/// Held in `@State`; mutating its cache during a view `body` is invisible to
/// SwiftUI (the `@State` reference itself is unchanged), so it caches without
/// triggering a re-render. Reactivity comes from the caller reading the
/// observed `generation` in `body`. Because the compute is synchronous there is
/// no first-frame flash and no cross-generation lag — a value derived from a
/// dependent memo recomputes in the same render pass.
final class Memoized<Value> {
    private var cached: Value?
    private var generation = Int.min

    func value(generation: Int, _ compute: () -> Value) -> Value {
        if let cached, generation == self.generation {
            return cached
        }
        let value = compute()
        cached = value
        self.generation = generation
        return value
    }
}
