import SwiftUI
import Inject

struct PingTabView: View {
    @ObserveInjection var inject
    @State private var viewModel = PingViewModel()
    @State private var draftSheet: DraftSheetItem? = nil

    /// Set by ContentView when a notification tap routes to a specific nudge.
    /// PingTabView scrolls to the nudge and clears this binding.
    var scrollToNudgeId: Binding<UUID?>

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            if viewModel.isLoading {
                                loadingPlaceholders
                            } else if viewModel.pendingNudges.isEmpty && viewModel.coolingContacts.isEmpty {
                                emptyState
                            } else {
                                // TODAY section
                                if !viewModel.pendingNudges.isEmpty {
                                    sectionHeader("TODAY")
                                    nudgesSection
                                }

                                // COOLING DOWN section
                                if !viewModel.coolingContacts.isEmpty {
                                    sectionHeader("COOLING DOWN")
                                    coolingSection
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                    .onChange(of: scrollToNudgeId.wrappedValue) { _, targetId in
                        guard let id = targetId else { return }
                        withAnimation {
                            proxy.scrollTo(id, anchor: .top)
                        }
                        scrollToNudgeId.wrappedValue = nil
                    }
                }
            }
            .navigationTitle("Ping")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.load()
                await NudgeService.shared.requestNotificationPermissionIfNeeded()
                if isLocalNotificationFallbackEnabled {
                    await scheduleLocalNotificationFallbacks()
                }
            }
            .sheet(item: $draftSheet) { item in
                MessageDraftView(
                    nudge: item.nudge,
                    contact: item.contact,
                    pingViewModel: viewModel
                )
            }
        }
        .enableInjection()
    }

    // MARK: - Local Notification Fallback

    /// Schedule local notifications for all pending nudges.
    /// These fire at nudge.scheduledAt and use the same userInfo payload as APNs,
    /// so the AppDelegate tap handler works without backend push setup.
    private func scheduleLocalNotificationFallbacks() async {
        for nudge in viewModel.pendingNudges {
            guard let contact = viewModel.contacts[nudge.contactId] else { continue }
            let body = nudge.draftMessage ?? nudge.reason ?? "Time to reconnect with \(contact.name)"
            await NudgeService.shared.scheduleLocalNotification(
                nudgeId: nudge.id,
                contactId: nudge.contactId,
                contactName: contact.name,
                body: body,
                at: nudge.scheduledAt
            )
        }
    }

    private var isLocalNotificationFallbackEnabled: Bool {
#if DEBUG
        let flag = ProcessInfo.processInfo.environment["LOCAL_PUSH_FALLBACK_ENABLED"]?.lowercased()
        return flag == nil || flag == "1" || flag == "true" || flag == "yes"
#else
        return false
#endif
    }

    // MARK: - Sections

    private var nudgesSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.pendingNudges) { nudge in
                if let contact = viewModel.contacts[nudge.contactId] {
                    NudgeCardView(
                        nudge: nudge,
                        contact: contact,
                        onDismiss: {
                            await NudgeService.shared.cancelLocalNotification(nudgeId: nudge.id)
                            await viewModel.dismissNudge(nudge)
                        },
                        onSnooze: { date in
                            await NudgeService.shared.cancelLocalNotification(nudgeId: nudge.id)
                            await viewModel.snoozeNudge(nudge, until: date)
                        },
                        onTap: {
                            draftSheet = DraftSheetItem(nudge: nudge, contact: contact)
                        }
                    )
                    .id(nudge.id)
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var coolingSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.coolingContacts.enumerated()), id: \.element.id) { index, contact in
                NavigationLink(destination: ContactDetailView(contact: contact)) {
                    ContactRowView(contact: contact)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                if index < viewModel.coolingContacts.count - 1 {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .pingCardShadow()
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var loadingPlaceholders: some View {
        VStack(spacing: 12) {
            sectionHeader("TODAY")
            ForEach(0..<2, id: \.self) { _ in
                ShimmerBox(height: 140, cornerRadius: 14)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 80)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pingSuccess)
            Text("All caught up")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.pingTextPrimary)
            Text("Your network looks great today")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.pingTextMuted)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Sheet Item

private struct DraftSheetItem: Identifiable {
    let id = UUID()
    let nudge: Nudge
    let contact: Contact
}

// MARK: - Preview

#Preview {
    PingTabView(scrollToNudgeId: .constant(nil))
}
