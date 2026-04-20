import SwiftUI
import UserNotifications
import Inject

struct PingTabView: View {
    @ObserveInjection var inject
    @State private var viewModel = PingViewModel()
    @State private var draftSheet: DraftSheetItem? = nil
    @State private var isCreatingNudge = false

    /// Set by ContentView when a notification tap routes to a specific nudge.
    /// PingTabView scrolls to the nudge and clears this binding.
    var scrollToNudgeId: Binding<UUID?>

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()

                if isCreatingNudge {
                    ProgressView()
                        .scaleEffect(1.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.pingBackground.opacity(0.6))
                        .zIndex(1)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            if viewModel.isLoading {
                                loadingPlaceholders
                            } else if viewModel.pendingNudges.isEmpty && viewModel.coolingContacts.isEmpty && viewModel.snoozedNudges.isEmpty {
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

                                // SNOOZED section
                                if !viewModel.snoozedNudges.isEmpty {
                                    sectionHeader("SNOOZED")
                                    snoozedSection
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
                await viewModel.generateMissingDrafts()
                // Only ask for notification permission once the user has real nudges to act on.
                if !viewModel.pendingNudges.isEmpty {
                    await NudgeService.shared.requestNotificationPermissionIfNeeded()
                }
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
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let scheduledIds = Set(pending.map { $0.identifier })

        for nudge in viewModel.pendingNudges {
            let identifier = nudge.id.uuidString
            guard !scheduledIds.contains(identifier) else { continue }
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
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        guard !isCreatingNudge else { return }
                        Task {
                            isCreatingNudge = true
                            defer { isCreatingNudge = false }
                            guard let userId = SupabaseService.shared.currentUserId else { return }
                            if let nudge = try? await SupabaseService.shared.createNudge(
                                contactId: contact.id,
                                userId: userId,
                                reason: "Cooling — reach out to keep the relationship warm"
                            ) {
                                draftSheet = DraftSheetItem(nudge: nudge, contact: contact)
                            }
                        }
                    } label: {
                        Label("Ping", systemImage: "bell.fill")
                    }
                    .tint(Color.pingAccent)
                }

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

    private var snoozedSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.snoozedNudges.enumerated()), id: \.element.id) { index, nudge in
                let contact = viewModel.contacts[nudge.contactId]
                HStack(spacing: 12) {
                    ContactAvatarView(name: contact?.name ?? "?", size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact?.name ?? "Unknown")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.pingTextPrimary)
                        if let until = nudge.snoozedUntil {
                            Text("Wakes up \(until.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(Color.pingTextMuted)
                        }
                    }

                    Spacer()

                    Button("Wake now") {
                        Task { await viewModel.unsnoozeNudge(nudge) }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.pingAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index < viewModel.snoozedNudges.count - 1 {
                    Divider().padding(.leading, 64)
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
            Image(systemName: viewModel.contacts.isEmpty ? "person.2" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(viewModel.contacts.isEmpty ? Color.pingTextMuted : Color.pingSuccess)
            Text(viewModel.contacts.isEmpty ? "Start building your network" : "All caught up")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.pingTextPrimary)
            Text(viewModel.contacts.isEmpty
                 ? "Add your first contact and Ping will remind you when to reach out."
                 : "Ping will remind you who to reach out to as your network grows.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextMuted)
                .multilineTextAlignment(.center)
            if viewModel.contacts.isEmpty {
                PingButton(title: "Add Your First Contact", action: {
                    NotificationCenter.default.post(name: .showQuickCapture, object: nil)
                }, style: .primary)
                .frame(maxWidth: 260)
                .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
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
