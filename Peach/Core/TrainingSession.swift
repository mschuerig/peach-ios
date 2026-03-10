protocol TrainingSession: AnyObject {
    func stop()
    var isIdle: Bool { get }
}
