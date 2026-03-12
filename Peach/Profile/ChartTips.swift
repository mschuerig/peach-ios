import SwiftUI
import TipKit

struct ChartOverviewTip: Tip {
    var title: Text {
        Text("Your Progress Chart", comment: "Chart overview tip title")
    }

    var message: Text? {
        Text("This chart shows how your pitch perception is developing over time", comment: "Chart overview tip message")
    }
}

struct EWMALineTip: Tip {
    var title: Text {
        Text("Trend Line", comment: "EWMA line tip title")
    }

    var message: Text? {
        Text("The blue line shows your smoothed average — it filters out random ups and downs to reveal your real progress", comment: "EWMA line tip message")
    }
}

struct StdDevBandTip: Tip {
    var title: Text {
        Text("Variability Band", comment: "Stddev band tip title")
    }

    var message: Text? {
        Text("The shaded area around the line shows how consistent you are — a narrower band means more reliable results", comment: "Stddev band tip message")
    }
}

struct BaselineTip: Tip {
    var title: Text {
        Text("Target Baseline", comment: "Baseline tip title")
    }

    var message: Text? {
        Text("The green dashed line is your goal — as the trend line approaches it, your ear is getting sharper", comment: "Baseline tip message")
    }
}

struct GranularityZoneTip: Tip {
    var title: Text {
        Text("Time Zones", comment: "Granularity zone tip title")
    }

    var message: Text? {
        Text("The chart groups your data by time: months on the left, recent days in the middle, and today's sessions on the right", comment: "Granularity zone tip message")
    }
}
