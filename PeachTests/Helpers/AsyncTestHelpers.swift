import Testing

@MainActor
func waitForCondition(
    timeout: Duration = .seconds(5),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async throws {
    await Task.yield()
    if condition() { return }
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(5))
        await Task.yield()
    }
    Issue.record("Timeout waiting for condition", sourceLocation: sourceLocation)
}
