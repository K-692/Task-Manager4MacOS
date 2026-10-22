import SwiftUI
import TaskManagerCore

/// Visual badge communicating explicit capability status without guessing.
public struct StatusBadge: View {
    public let status: CapabilityStatus

    public init(status: CapabilityStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            Text(status.label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.12))
        .foregroundColor(badgeColor)
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch status {
        case .available: return "checkmark.circle.fill"
        case .notPresent: return "slash.circle"
        case .unsupportedByOS: return "exclamationmark.triangle.fill"
        case .notExposedBySupportedAPI: return "eye.slash.fill"
        case .restricted: return "lock.fill"
        case .permissionRequired: return "hand.raised.fill"
        case .temporarilyUnavailable: return "clock.fill"
        case .probeFailed: return "xmark.octagon.fill"
        }
    }

    private var badgeColor: Color {
        switch status {
        case .available: return .emerald
        case .notPresent: return .slate
        case .unsupportedByOS: return .amber
        case .notExposedBySupportedAPI: return .slate
        case .restricted: return .amber
        case .permissionRequired: return .purple
        case .temporarilyUnavailable: return .amber
        case .probeFailed: return .rose
        }
    }
}
