/// A type whose accumulated state can be cleared back to its initial condition.
protocol Resettable {
    func reset()
}
