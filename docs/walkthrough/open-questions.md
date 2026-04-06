# Open Questions

Questions, topics to revisit, and things to dig deeper into.

<!-- Add entries as they come up during walkthrough sessions -->

## Research topics

1. **Explicit state machine patterns in Swift.** All four session classes interweave state transitions with side effects (audio, persistence, UI, scheduling). Research the `state + event → (newState, [Effect])` pattern and other idiomatic Swift approaches (e.g. enums with associated values for state, separate effect interpreters). Evaluate feasibility and payoff for the session classes. (Layer 3, observation #3)
