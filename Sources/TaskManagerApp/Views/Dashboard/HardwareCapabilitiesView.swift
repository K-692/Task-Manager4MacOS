import SwiftUI
import TaskManagerCore

/// Hardware & Capabilities view: full model-adaptive inventory with explicit capability states.
public struct HardwareCapabilitiesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedCategory: HardwareCategory? = nil
    @State private var searchQuery: String = ""

    public init() {}

    public var body: some View {
        let allRecords = env.capabilities
        let filtered = allRecords.filter { rec in
            if let cat = selectedCategory, rec.category != cat {
                return false
            }
            if !searchQuery.isEmpty {
                let matchName = rec.displayName.localizedCaseInsensitiveContains(searchQuery)
                let matchVal = rec.valueString?.localizedCaseInsensitiveContains(searchQuery) ?? false
                let matchSrc = rec.source.localizedCaseInsensitiveContains(searchQuery)
                let matchExp = rec.explanation?.localizedCaseInsensitiveContains(searchQuery) ?? false
                if !matchName && !matchVal && !matchSrc && !matchExp {
                    return false
                }
            }
            return true
        }

        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hardware & Capabilities")
                            .font(.system(size: 26, weight: .bold))
                        Text("Truthful runtime capability discovery across Apple Silicon and Intel Macs.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        env.reloadCapabilities()
                    }) {
                        Label("Re-scan Hardware", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Search & Category Filters
                CardView {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search capability or source API...", text: $searchQuery)
                                .textFieldStyle(.plain)

                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                Button("All (\(allRecords.count))") {
                                    selectedCategory = nil
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selectedCategory == nil ? AppTheme.Colors.primaryAccent.opacity(0.15) : Color.primary.opacity(0.04))
                                .foregroundColor(selectedCategory == nil ? AppTheme.Colors.primaryAccent : .primary)
                                .clipShape(Capsule())

                                ForEach(HardwareCategory.allCases, id: \.self) { cat in
                                    let isSel = selectedCategory == cat
                                    Button(action: { selectedCategory = cat }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: cat.systemImage)
                                                .font(.system(size: 10))
                                            Text(cat.displayName)
                                                .font(.system(size: 11, weight: isSel ? .bold : .medium))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(isSel ? AppTheme.Colors.primaryAccent.opacity(0.15) : Color.primary.opacity(0.04))
                                        .foregroundColor(isSel ? AppTheme.Colors.primaryAccent : .primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Inventory Table
                CardView {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Category & Capability").font(.caption.bold()).frame(width: 240, alignment: .leading)
                            Text("Reading / Value").font(.caption.bold()).frame(width: 180, alignment: .leading)
                            Text("Capability State").font(.caption.bold()).frame(width: 170, alignment: .leading)
                            Spacer()
                            Text("Source & Provenance").font(.caption.bold()).frame(width: 180, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        .foregroundColor(.secondary)

                        Divider()

                        ForEach(filtered) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    HStack(spacing: 8) {
                                        Image(systemName: record.category.systemImage)
                                            .foregroundColor(.indigo)
                                            .frame(width: 16)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(record.displayName)
                                                .font(.system(size: 13, weight: .semibold))
                                            Text(record.category.displayName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 240, alignment: .leading)

                                    Group {
                                        if let val = record.valueString {
                                            Text(val)
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                        } else {
                                            Text("—")
                                                .foregroundColor(.secondary.opacity(0.5))
                                        }
                                    }
                                    .frame(width: 180, alignment: .leading)

                                    StatusBadge(status: record.status)
                                        .frame(width: 170, alignment: .leading)

                                    Spacer()

                                    Text(record.source)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                        .frame(width: 180, alignment: .trailing)
                                }

                                if let explanation = record.explanation {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text(explanation)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 24)
                                    .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 8)

                            Divider()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.bottom, AppTheme.Spacing.xxl)
        }
    }
}
