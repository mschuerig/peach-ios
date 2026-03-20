import Foundation

extension Duration {
    var timeInterval: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
