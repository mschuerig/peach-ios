enum AudioError: Error {
    case engineStartFailed(String)
    case invalidFrequency(String)
    case invalidDuration(String)
    case invalidPreset(String)
    case contextUnavailable
    case invalidInterval(String)
}
