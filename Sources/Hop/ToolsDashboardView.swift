import HopCore
import SwiftUI

struct ToolsDashboardModule: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
}

/// Compact action-first landing for the semantic Tools space.
///
/// All executable tiles are the same typed HopAction values used by command
/// search. "Full tools" is a compatibility/drilldown surface over the existing
/// modules so no advanced control disappears behind the redesign.
struct ToolsDashboardView: View {
    let availableActions: [HopAction]
    let favoriteIDs: [String]
    let modules: [ToolsDashboardModule]
    let executeAction: (HopAction) -> Void
    let toggleFavorite: (HopAction) -> Void
    let openModule: (String) -> Void

    private let actionColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
    ]

    private let favoriteColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    private var favorites: [HopAction] {
        let byID = Dictionary(uniqueKeysWithValues: availableActions.map { ($0.id, $0) })
        return favoriteIDs.compactMap { byID[$0] }
    }

    private var captureActions: [HopAction] {
        availableActions.filter { $0.category == .capture }
    }

    private var fileActions: [HopAction] {
        availableActions.filter { $0.category == .files }
    }

    private var windowActions: [HopAction] {
        availableActions.filter { $0.category == .windows }
    }

    private var otherActions: [HopAction] {
        availableActions.filter {
            $0.category != .capture && $0.category != .files && $0.category != .windows
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            favoritesSection

            if !captureActions.isEmpty {
                actionSection(
                    title: "Capture",
                    symbol: "camera.viewfinder",
                    actions: captureActions
                )
            }

            if !fileActions.isEmpty {
                actionSection(
                    title: "Files",
                    symbol: "folder",
                    actions: fileActions
                )
            }

            if !windowActions.isEmpty {
                actionSection(
                    title: "Windows",
                    symbol: "rectangle.split.2x1",
                    actions: windowActions
                )
            }

            if !otherActions.isEmpty {
                actionSection(
                    title: "Other",
                    symbol: "square.grid.2x2",
                    actions: otherActions
                )
            }

            if !modules.isEmpty {
                fullToolsSection
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tools")
                    .font(Theme.mono(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Fast actions and utilities")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text("★ up to \(ToolsFavorites.maximumCount)")
                .font(Theme.mono(7, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Favorites", symbol: "star.fill", detail: "Tap ★ below to edit")

            if favorites.isEmpty {
                Text("No visible favorites · star any action below")
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .padding(.horizontal, 2)
            } else {
                LazyVGrid(columns: favoriteColumns, spacing: 6) {
                    ForEach(favorites) { action in
                        favoriteTile(action)
                    }
                }
            }
        }
        .padding(9)
        .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Theme.divider, lineWidth: 1)
        )
    }

    private func actionSection(
        title: String,
        symbol: String,
        actions: [HopAction]
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader(title, symbol: symbol)

            LazyVGrid(columns: actionColumns, spacing: 7) {
                ForEach(actions) { action in
                    actionTile(action)
                }
            }
        }
    }

    private var fullToolsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader(
                "Full tools",
                symbol: "slider.horizontal.3",
                detail: "Advanced controls"
            )

            LazyVGrid(columns: actionColumns, spacing: 6) {
                ForEach(modules) { module in
                    Button {
                        openModule(module.id)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: module.systemImage)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 17)
                            Text(module.title)
                                .font(Theme.mono(8, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 3)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 31)
                        .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.divider, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight(6)
                    .help("Open full \(module.title)")
                }
            }
        }
    }

    private func favoriteTile(_ action: HopAction) -> some View {
        Button {
            executeAction(action)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(height: 18)
                Text(shortTitle(action))
                    .font(Theme.mono(7, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Theme.chipBg, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(7)
        .contextMenu {
            Button("Remove from Favorites") {
                toggleFavorite(action)
            }
        }
        .help(action.title)
    }

    private func actionTile(_ action: HopAction) -> some View {
        let favorite = favoriteIDs.contains(action.id)
        let atLimit = favoriteIDs.count >= ToolsFavorites.maximumCount

        return HStack(spacing: 4) {
            Button {
                executeAction(action)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: action.systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shortTitle(action))
                            .font(Theme.mono(8, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text(actionSubtitle(action))
                            .font(Theme.mono(7))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                }
                .padding(.leading, 8)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                toggleFavorite(action)
            } label: {
                Image(systemName: favorite ? "star.fill" : "star")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(favorite ? Theme.accentYellow : Theme.textTertiary)
                    .frame(width: 24, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!favorite && atLimit)
            .help(
                favorite
                    ? "Remove from Favorites"
                    : (atLimit ? "Favorites are full" : "Add to Favorites")
            )
        }
        .background(Theme.rowBg, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Theme.divider, lineWidth: 1)
        )
        .hoverHighlight(7)
    }

    private func sectionHeader(
        _ title: String,
        symbol: String,
        detail: String? = nil
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(Theme.mono(9, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let detail {
                Text(detail)
                    .font(Theme.mono(7))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func shortTitle(_ action: HopAction) -> String {
        switch action.id {
        case "capture.screenshotToolbar": return "Screenshot"
        case "capture.area": return "Capture Area"
        case "capture.ocr": return "OCR"
        case "capture.markup": return "Draw"
        case "files.convert": return "Converter"
        case "files.archive": return "Archive"
        case "files.uninstall": return "Uninstaller"
        case "window.minimize": return "Minimize"
        case "window.maximize": return "Maximize"
        case "window.leftHalf": return "Left Half"
        case "window.rightHalf": return "Right Half"
        default: return action.title
        }
    }

    private func actionSubtitle(_ action: HopAction) -> String {
        switch action.category {
        case .capture: return "screen"
        case .files: return "files"
        case .windows: return "current window"
        case .focus: return "focus"
        case .network: return "network"
        case .navigate: return "open"
        }
    }
}
