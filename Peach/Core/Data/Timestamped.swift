import Foundation

/// A type that has a timestamp, enabling generic sorted fetches from the data store.
protocol Timestamped {
    var timestamp: Date { get }
}
