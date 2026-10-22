import SwiftUI

/// Ultra-lightweight, high-frequency real-time sparkline graph for sidebar telemetry.
public struct SparklineView: View {
    public let data: [Double]
    public let minVal: Double
    public let maxVal: Double
    public let tint: Color

    public init(
        data: [Double],
        minVal: Double = 0.0,
        maxVal: Double = 100.0,
        tint: Color = .indigo
    ) {
        self.data = data
        self.minVal = minVal
        self.maxVal = maxVal
        self.tint = tint
    }

    public var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }

            let width = size.width
            let height = size.height

            // Calculate range
            let range = max(1.0, maxVal - minVal)
            let stepX = width / CGFloat(max(1, data.count - 1))

            // Build line path
            var path = Path()
            for (index, val) in data.enumerated() {
                let clamped = min(maxVal, max(minVal, val))
                let normalized = (clamped - minVal) / range
                let x = CGFloat(index) * stepX
                let y = height - (CGFloat(normalized) * (height - 2)) - 1

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Fill gradient path
            var fillPath = path
            fillPath.addLine(to: CGPoint(x: width, y: height))
            fillPath.addLine(to: CGPoint(x: 0, y: height))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.3), tint.opacity(0.0)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: height)
                )
            )

            // Stroke line
            context.stroke(
                path,
                with: .color(tint),
                lineWidth: 1.5
            )
        }
        .frame(width: 52, height: 16)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
