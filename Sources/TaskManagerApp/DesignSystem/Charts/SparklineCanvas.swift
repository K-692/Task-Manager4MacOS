import SwiftUI

/// Ultra-lightweight SwiftUI Canvas sparkline for compact telemetry and activity cards.
public struct SparklineCanvas: View {
    public let dataPoints: [Double]
    public let lineColor: Color
    public let showFill: Bool

    public init(dataPoints: [Double], lineColor: Color = .indigo, showFill: Bool = true) {
        self.dataPoints = dataPoints
        self.lineColor = lineColor
        self.showFill = showFill
    }

    public var body: some View {
        Canvas { context, size in
            guard dataPoints.count > 1 else { return }

            let minVal = dataPoints.min() ?? 0.0
            let maxVal = max(minVal + 0.01, dataPoints.max() ?? 100.0)
            let range = maxVal - minVal

            let stepX = size.width / CGFloat(dataPoints.count - 1)

            var path = Path()
            var fillPath = Path()

            for (index, val) in dataPoints.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedY = CGFloat((val - minVal) / range)
                let y = size.height - (normalizedY * (size.height - 4)) - 2

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                    fillPath.move(to: CGPoint(x: x, y: size.height))
                    fillPath.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                    fillPath.addLine(to: CGPoint(x: x, y: y))
                }

                if index == dataPoints.count - 1 {
                    fillPath.addLine(to: CGPoint(x: x, y: size.height))
                    fillPath.closeSubpath()
                }
            }

            if showFill {
                let fillGradient = Gradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0.0)])
                context.fill(fillPath, with: .linearGradient(fillGradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            }

            context.stroke(path, with: .color(lineColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            // Latest point dot
            if let lastVal = dataPoints.last {
                let x = size.width
                let normalizedY = CGFloat((lastVal - minVal) / range)
                let y = size.height - (normalizedY * (size.height - 4)) - 2
                let dotRect = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
                context.fill(Circle().path(in: dotRect), with: .color(lineColor))
            }
        }
        .frame(height: 36)
    }
}
