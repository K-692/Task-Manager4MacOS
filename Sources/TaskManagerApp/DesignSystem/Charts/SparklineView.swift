import SwiftUI

/// Ultra-lightweight, high-frequency real-time sparkline graph for sidebar telemetry.
public struct SparklineView: View {
    public let data: [Double]
    public let minVal: Double
    public let maxVal: Double
    public let tint: Color
    public let capacity: Int

    public init(
        data: [Double],
        minVal: Double = 0.0,
        maxVal: Double = 100.0,
        tint: Color = .indigo,
        capacity: Int = 60
    ) {
        self.data = data
        self.minVal = minVal
        self.maxVal = maxVal
        self.tint = tint
        self.capacity = capacity
    }

    public var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            guard data.count > 1 else { return }

            let range = max(0.001, maxVal - minVal)
            let totalSlots = max(capacity, data.count)
            let stepX = width / CGFloat(max(1, totalSlots - 1))
            let offsetIndex = totalSlots - data.count

            // Draw subtle horizontal center gridline
            var gridPath = Path()
            gridPath.move(to: CGPoint(x: 0, y: height / 2.0))
            gridPath.addLine(to: CGPoint(x: width, y: height / 2.0))
            context.stroke(gridPath, with: .color(Color.primary.opacity(0.08)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

            // Build line path
            var path = Path()
            var lastPoint: CGPoint?

            for (index, val) in data.enumerated() {
                let clamped = min(maxVal, max(minVal, val))
                let normalized = (clamped - minVal) / range
                let x = CGFloat(index + offsetIndex) * stepX
                let y = height - (CGFloat(normalized) * (height - 4)) - 2

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                lastPoint = CGPoint(x: x, y: y)
            }

            // Fill gradient path
            var fillPath = path
            if let last = lastPoint {
                fillPath.addLine(to: CGPoint(x: last.x, y: height))
                fillPath.addLine(to: CGPoint(x: CGFloat(offsetIndex) * stepX, y: height))
                fillPath.closeSubpath()

                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [tint.opacity(0.35), tint.opacity(0.0)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: height)
                    )
                )
            }

            // Stroke line
            context.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            // Live current value dot
            if let last = lastPoint {
                let dotRect = CGRect(x: last.x - 2, y: last.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dotRect), with: .color(tint))
            }
        }
        .frame(width: 60, height: 18)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}
