import ConferenceKit
import SwiftUI

struct SessionRow: View {
    let session: Session
    let store: ConferenceStore
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.clock.timeString(session.startTime, style: store.timeDisplay))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                if store.favorites.contains(session.id) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Favorited")
                }
                Spacer(minLength: 8)
                Text(session.kind.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(session.title)
                .font(emphasized ? .title3.weight(.semibold) : .headline)
            HStack {
                if let room = store.roomName(for: session) {
                    Label(room, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                let names = store.speakers(for: session).map(\.name).joined(separator: ", ")
                if !names.isEmpty {
                    Text(names)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let track = store.track(for: session) {
                Text(track.name)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((track.swiftColor ?? store.theme.accentColor).opacity(0.18), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SpeakerAvatar: View {
    let speaker: Speaker
    var diameter: CGFloat = 44

    var body: some View {
        AsyncImage(url: speaker.photoURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct TimeRangeLabel: View {
    let session: Session
    let store: ConferenceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.clock.rangeString(from: session.startTime, to: session.endTime, style: store.timeDisplay))
                .font(.headline)
            if store.clock.timeZone != .current {
                let other: TimeDisplay = store.timeDisplay == .conference ? .device : .conference
                Text(store.clock.rangeString(from: session.startTime, to: session.endTime, style: other))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(other == .device ? "Device time" : "Conference time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct DayStrip: View {
    let days: [ConferenceDay]
    let clock: ConferenceClock
    @Binding var selection: Date?

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                chip("All", day: nil)
                ForEach(days) { day in
                    chip(clock.dayString(day.start), day: day.start)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        #if os(watchOS) || os(tvOS)
        .background(.ultraThinMaterial)
        #else
        .background(.bar)
        #endif
    }

    private func chip(_ title: String, day: Date?) -> some View {
        let selected = day.map { selection == $0 } ?? (selection == nil)
        return Button {
            selection = day
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12), in: Capsule())
                // The capsule keeps its compact look; the tappable area is a full hit target.
                .frame(minHeight: CKSize.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A list row that opens a route. The whole row is the hit target, a pushed row shows the
/// disclosure chevron, and a row feeding a split view shows that it is selected.
struct RouteRow<Content: View>: View {
    var push: Bool
    var selected = false
    var action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                #if os(iOS)
                if push {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                #endif
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(selected ? Color.accentColor.opacity(0.12) : nil)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A confirmation that fades after a few seconds, on the bar material above the content.
/// Anything that needs a decision is an alert; "Reminder set" and "Added to Calendar" are not.
struct StatusToast: ViewModifier {
    var router: ConferenceRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let message = router.statusMessage {
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .onAppear { AccessibilityNotification.Announcement(message).post() }
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(4))
                            if router.statusMessage == message { router.statusMessage = nil }
                        }
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: router.statusMessage)
    }
}

extension View {
    func statusToast(_ router: ConferenceRouter) -> some View { modifier(StatusToast(router: router)) }
}

struct EmptyPane: View {
    var title: String
    var systemImage: String
    var message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

struct StatusBanner: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)
    }
}

extension View {
    @ViewBuilder
    func scheduleScrollFade() -> some View {
        visualEffect { content, geometry in
            let minY = geometry.frame(in: .scrollView(axis: .vertical)).minY
            let fade = min(1, max(0.55, 1 - max(0, -minY) / 280))
            return content.opacity(fade)
        }
    }
}
