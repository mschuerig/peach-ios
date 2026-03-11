import Foundation
import CoreGraphics

/// Describes a contiguous range of buckets sharing the same granularity.
struct ZoneBoundary {
    let startIndex: Int
    let endIndex: Int
    let bucketSize: BucketSize
}

/// Computes chart layout geometry from multi-granularity bucket arrays.
///
/// Pure stateless utility — all methods are static with no side effects.
enum ChartLayoutCalculator {

    /// Computes total chart width from bucket count × per-granularity point widths.
    static func totalWidth(for buckets: [TimeBucket], configs: [BucketSize: any GranularityZoneConfig]) -> CGFloat {
        buckets.reduce(CGFloat(0)) { total, bucket in
            total + (configs[bucket.bucketSize]?.pointWidth ?? 0)
        }
    }

    /// Returns zone boundaries marking where granularity transitions occur.
    static func zoneBoundaries(for buckets: [TimeBucket]) -> [ZoneBoundary] {
        guard let first = buckets.first else { return [] }

        var boundaries: [ZoneBoundary] = []
        var currentStart = 0
        var currentSize = first.bucketSize

        for i in 1..<buckets.count {
            if buckets[i].bucketSize != currentSize {
                boundaries.append(ZoneBoundary(startIndex: currentStart, endIndex: i - 1, bucketSize: currentSize))
                currentStart = i
                currentSize = buckets[i].bucketSize
            }
        }
        boundaries.append(ZoneBoundary(startIndex: currentStart, endIndex: buckets.count - 1, bucketSize: currentSize))

        return boundaries
    }
}
