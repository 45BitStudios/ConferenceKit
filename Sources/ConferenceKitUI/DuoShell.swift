import ConferenceKit
import SwiftUI

struct MeasureToken: Equatable {
    var size: CGSize
    var division: DivisionMeasurement
}

struct ContainerMeasure: ViewModifier {
    @Binding var size: CGSize
    @Binding var division: DivisionMeasurement

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            content.onGeometryChange(for: MeasureToken.self) { proxy in
                MeasureToken(size: proxy.size, division: Self.readDivision(proxy))
            } action: { token in
                size = token.size
                division = token.division
            }
        } else {
            content.background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { size = proxy.size }
                        .onChange(of: proxy.size) { _, newValue in size = newValue }
                }
            }
        }
    }

    nonisolated static func readDivision(_ proxy: GeometryProxy) -> DivisionMeasurement {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            let regions = proxy.reservedRegions(kind: .division)
            guard let region = regions.first(where: \.isActive) ?? regions.first else { return .inactive }
            let frame = region.frame
            return DivisionMeasurement(
                active: region.isActive,
                width: frame.width,
                height: frame.height,
                minX: frame.minX,
                minY: frame.minY
            )
        }
        #endif
        return .inactive
    }
}

/// Hinge angle drives a small tilt on the session title. It is not a layout input.
struct HingeTilt: ViewModifier {
    @Binding var tilt: Double

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                if let hinge = context.hinge, hinge.status == .partiallyOpen {
                    tilt = min(8, abs(180 - hinge.angle.degrees) * 0.05)
                } else {
                    tilt = 0
                }
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

struct DuoPanes<Primary: View, Secondary: View>: View {
    var pose: DuoPose
    var division: DivisionMeasurement
    var container: CGSize
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        let split = FoldSplit.measure(
            containerWidth: container.width,
            containerHeight: container.height,
            division: division
        )
        #if os(iOS)
        if #available(iOS 27.1, *) {
            systemOrRegions(split)
        } else {
            regions(split)
        }
        #else
        regions(split)
        #endif
    }

    #if os(iOS)
    @available(iOS 27.1, *)
    @ViewBuilder
    private func systemOrRegions(_ split: FoldSplit) -> some View {
        // ArrangementView drops the secondary pane when the requested axis
        // is not the container's long axis. A wide laptop (horizontal crease)
        // uses the division region directly so the notes deck stays on screen.
        if pose == .book, container.width >= container.height, container.width > 0 {
            ArrangementView {
                primary()
            } secondary: {
                secondary()
            }
            .arrangementViewStyle(.split.axes(.horizontal))
        } else if pose == .laptop, container.height > container.width, container.height > 0 {
            ArrangementView {
                primary()
            } secondary: {
                secondary()
            }
            .arrangementViewStyle(.split.axes(.vertical))
        } else {
            regions(split)
        }
    }
    #endif

    @ViewBuilder
    private func regions(_ split: FoldSplit) -> some View {
        switch split.axis {
        case .horizontal:
            VStack(spacing: 0) {
                primary()
                    .frame(maxWidth: .infinity, maxHeight: split.primaryExtent > 1 ? split.primaryExtent : .infinity)
                Color.clear
                    .frame(height: max(split.band, 0))
                    .accessibilityHidden(true)
                secondary()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .vertical:
            HStack(spacing: 0) {
                primary()
                    .frame(maxWidth: split.primaryExtent > 1 ? split.primaryExtent : .infinity, maxHeight: .infinity)
                Color.clear
                    .frame(width: max(split.band, 0))
                    .accessibilityHidden(true)
                secondary()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .none:
            if pose == .laptop {
                VStack(spacing: 0) {
                    primary()
                    Divider()
                    secondary()
                }
            } else {
                HStack(spacing: 0) {
                    primary()
                    Divider()
                    secondary()
                }
            }
        }
    }
}

struct BookShell: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var division: DivisionMeasurement
    var container: CGSize

    var body: some View {
        DuoPanes(pose: .book, division: division, container: container) {
            ScheduleList(store: store, router: router, push: false)
        } secondary: {
            detail
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = router.selectedSessionID, let session = store.session(id: id) {
            SessionDetail(store: store, router: router, session: session, push: false, showsInlineNotes: true)
        } else {
            EmptyPane(title: "Schedule", systemImage: "calendar", message: "Choose a session. The crease keeps the list on the other side.")
        }
    }
}

struct LaptopShell: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var division: DivisionMeasurement
    var container: CGSize
    var tilt: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let sessionID = LiveSessionFollow.sessionID(
                sessions: store.sessions,
                pinnedID: router.selectedSessionID,
                followLive: router.followLive,
                now: context.date
            )
            DuoPanes(pose: .laptop, division: division, container: container) {
                LiveSessionStage(
                    store: store,
                    router: router,
                    session: sessionID.flatMap { store.session(id: $0) },
                    tilt: tilt
                )
                .modifier(OcclusionPadding())
            } secondary: {
                if router.showsNotes, let sessionID, let session = store.session(id: sessionID) {
                    VStack(spacing: 0) {
                        HStack {
                            Button {
                                router.showsNotes = false
                            } label: {
                                Label("Schedule", systemImage: "calendar")
                            }
                            Spacer()
                            Button {
                                router.setFollowLive(!router.followLive)
                            } label: {
                                Label(router.followLive ? "Following" : "Follow live", systemImage: "dot.radiowaves.left.and.right")
                            }
                            .accessibilityAddTraits(router.followLive ? .isSelected : [])
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        NotesEditor(store: store, session: session)
                    }
                } else {
                    ScheduleList(store: store, router: router, push: false)
                }
            }
            .onChange(of: sessionID) { _, newID in
                if router.followLive, router.showsNotes, let newID {
                    router.selectedSessionID = newID
                }
            }
        }
    }
}

struct OcclusionPadding: ViewModifier {
    @State private var extraTop: CGFloat = 0

    func body(content: Content) -> some View {
        content.padding(.top, extraTop)
            .onGeometryChangeIfAvailable { proxy in
                #if os(iOS)
                if #available(iOS 27.1, *) {
                    let frames = proxy.reservedRegions(kind: .occlusion).map(\.frame)
                    extraTop = frames.map(\.maxY).max() ?? 0
                    if extraTop > proxy.size.height * 0.45 { extraTop = 0 }
                }
                #endif
            }
    }
}

private extension View {
    @ViewBuilder
    func onGeometryChangeIfAvailable(_ apply: @escaping (GeometryProxy) -> Void) -> some View {
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *) {
            onGeometryChange(for: CGSize.self, of: \.size) { _ in }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { apply(proxy) }
                            .onChange(of: proxy.size) { _, _ in apply(proxy) }
                    }
                }
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func conferenceCoverCompanion(enabled: Binding<Bool>, available: Binding<Bool>, title: String) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *), enabled.wrappedValue {
            sceneAccessory {
                CameraCaptureAccessory(isEnabled: enabled) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.isEmpty ? "Slide photo" : title)
                            .font(.headline)
                        Text("Photographing a slide")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .onAvailabilityChange { available.wrappedValue = $0 }
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
