import SwiftUI

struct StartScreen: View {
    @State private var showInfoSheet = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.trainingLifecycle) private var lifecycle

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    // MARK: - Layout Parameters (extracted for testability)

    static func sectionSpacing(isCompact: Bool) -> CGFloat {
        isCompact ? 24 : 28
    }

    static func cardSpacing(isCompact: Bool) -> CGFloat {
        isCompact ? 6 : 10
    }

    static let cardCornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if isCompactHeight {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .padding()
        .navigationTitle("Peach")
        .inlineNavigationBarTitle()
        .platformPrincipalTitle("Peach")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Info")
            }
            ToolbarItemGroup(placement: .automatic) {
                NavigationLink(value: NavigationDestination.profile) {
                    Image(systemName: "chart.xyaxis.line")
                }
                .accessibilityLabel("Profile")

                PlatformSettingsButton()
            }
        }
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .pitchDiscrimination(let isIntervalMode):
                PitchDiscriminationScreen(isIntervalMode: isIntervalMode)
            case .pitchMatching(let isIntervalMode):
                PitchMatchingScreen(isIntervalMode: isIntervalMode)
            case .settings:
                SettingsScreen()
            case .profile:
                ProfileScreen()
            case .timingOffsetDetection:
                TimingOffsetDetectionScreen()
            case .continuousRhythmMatching:
                ContinuousRhythmMatchingScreen()
            case .chromaticConstruction:
                #if PEACH_RESEARCH
                ChromaticConstructionScreen()
                #else
                EmptyView()
                #endif
            }
        }
        .platformHelp(
            isPresented: $showInfoSheet,
            title: String(localized: "About Peach"),
            iosSheet: { InfoScreen() },
            macPanel: { InfoContentView() }
        )
        .onAppear {
            lifecycle.startScreenAppeared()
        }
    }

    // MARK: - Layouts

    private var portraitLayout: some View {
        ScrollView(.vertical) {
            VStack(spacing: Self.sectionSpacing(isCompact: false)) {
                ForEach(TrainingDisciplineRegistry.shared.activeCategories, id: \.self) { category in
                    categorySection(category)
                }
            }
            .padding(.vertical)
        }
    }

    private var landscapeLayout: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: Self.sectionSpacing(isCompact: true)) {
                ForEach(TrainingDisciplineRegistry.shared.activeCategories, id: \.self) { category in
                    categorySection(category)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Sections

    private func categorySection(_ category: TrainingCategory) -> some View {
        VStack(spacing: Self.cardSpacing(isCompact: isCompactHeight)) {
            Text(category.localizedTitle)
                .font(.title3)
                .foregroundStyle(.secondary)

            ForEach(TrainingDisciplineRegistry.shared.disciplines(in: category), id: \.id) { discipline in
                NavigationLink(value: discipline.navigationDestination) {
                    trainingCard(for: discipline)
                }
                .buttonStyle(TrainingCardButtonStyle())
                .accessibilityLabel(discipline.config.displayName)
            }
        }
    }

    // MARK: - Card View

    private func trainingCard(for discipline: any TrainingDiscipline) -> some View {
        let config = discipline.config
        let mode = discipline.id
        return CachedProgress(mode: mode) { progress in
            VStack(alignment: .leading, spacing: 4) {
                Label(config.shortLabel, systemImage: config.systemImageName)
                ProgressSparklineView(
                    state: progress.state,
                    bucketMeans: progress.buckets.map(\.mean),
                    ewma: progress.ewma,
                    trend: progress.trend,
                    modeName: config.displayName,
                    unitLabel: config.unitLabel
                )
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: Self.cardCornerRadius)
                    .fill(config.isHero ? .thinMaterial : .regularMaterial)
            )
            .overlay {
                if config.isHero {
                    RoundedRectangle(cornerRadius: Self.cardCornerRadius)
                        .strokeBorder(.tint.opacity(0.3), lineWidth: 1)
                }
            }
        }
    }
}

private struct TrainingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Rectangle())
            .platformHoverEffect()
    }
}

#if DEBUG
#Preview {
    PreviewSupport.bootstrapRegistryIfNeeded()
    return NavigationStack {
        StartScreen()
    }
}
#endif
