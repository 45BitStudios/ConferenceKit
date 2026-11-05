import ConferenceKit
import SwiftUI
#if canImport(PhotosUI) && (os(iOS) || os(macOS) || os(visionOS))
import PhotosUI
#endif
#if os(iOS)
import UIKit
#endif

struct NotesEditor: View {
    @Bindable var store: ConferenceStore
    var session: Session?
    /// False when the editor is inline in session detail, so the detail keeps its own title.
    var setsTitle = true
    @State private var draft = ""
    @State private var draftSessionID: String?
    @State private var showCamera = false
    #if canImport(PhotosUI) && (os(iOS) || os(macOS) || os(visionOS))
    @State private var photoItem: PhotosPickerItem?
    #endif

    private var notes: NotesStore? { store.notesStore }
    private var saved: [SessionNote] {
        guard let session, let notes else { return [] }
        return notes.notes(for: session.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if saved.isEmpty {
                        Text("Notes stay on this device. Timestamp, star, or mark a takeaway.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(saved) { note in
                        NoteCard(note: note, store: store)
                            .siriEntity(.note(note.id))
                    }
                }
                .padding()
            }
            #if !os(tvOS)
            quickActions
            #endif
            editor
        }
        .notesTitle(setsTitle)
        .onChange(of: session?.id) { _, newID in
            commitIfNeeded(previousSessionID: draftSessionID)
            draftSessionID = newID
        }
        .onAppear { draftSessionID = session?.id }
        #if os(iOS)
        .sheet(isPresented: $showCamera) {
            SlideCamera { data in
                guard let session else { return }
                _ = try? notes?.addPhoto(data: data, session: session, caption: draft)
                draft = ""
            }
        }
        #endif
        #if canImport(PhotosUI) && (os(iOS) || os(macOS) || os(visionOS))
        .onChange(of: photoItem) { _, item in
            guard let item, let session else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    _ = try? notes?.addPhoto(data: data, session: session, caption: draft)
                    draft = ""
                }
                photoItem = nil
            }
        }
        #endif
    }

    private var quickActions: some View {
        ScrollView(.horizontal) {
            HStack {
                action("Timestamp", systemImage: "clock.badge") { commit(kind: .timestamp) }
                action("Takeaway", systemImage: "bookmark") { commit(kind: .takeaway, takeaway: true) }
                action("Star", systemImage: "star") { star() }
                if SlideCaptureController.shared.isRunning {
                    action("Slide", systemImage: "camera.viewfinder") {
                        Task { await captureSlide() }
                    }
                }
                #if os(iOS)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    action("Camera", systemImage: "camera") { showCamera = true }
                }
                #endif
                #if canImport(PhotosUI) && (os(iOS) || os(macOS) || os(visionOS))
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photo", systemImage: "photo")
                }
                .buttonStyle(.bordered)
                #endif
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .accessibilityLabel("Note actions")
    }

    private var editor: some View {
        #if os(tvOS)
        Text(draft.isEmpty ? "Notes are read-only on Apple TV." : draft)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        #elseif os(watchOS)
        TextField("Session note", text: $draft, axis: .vertical)
            .font(.body)
            .padding()
        #else
        TextEditor(text: $draft)
            .font(.body)
            .padding(8)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            .padding()
            .accessibilityLabel("Session note")
        #endif
    }

    private func action(_ title: String, systemImage: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
    }

    private func commit(kind: SessionNoteKind, takeaway: Bool = false, starred: Bool = false) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let session else { return }
        _ = notes?.add(body: text, session: session, kind: kind, starred: starred, takeaway: takeaway)
        SiriDonations.note(store, text: text, session: session)
        draft = ""
    }

    private func captureSlide() async {
        guard let session, let data = await SlideCaptureController.shared.takePhoto() else { return }
        _ = try? notes?.addPhoto(data: data, session: session, caption: draft.isEmpty ? "Slide" : draft)
        draft = ""
    }

    private func star() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty, let last = saved.last {
            notes?.toggleStar(last.id)
        } else {
            commit(kind: .text, starred: true)
        }
    }

    private func commitIfNeeded(previousSessionID: String?) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let previousSessionID, let session = store.session(id: previousSessionID) else { return }
        _ = notes?.add(body: text, session: session, kind: .text)
        draft = ""
    }
}

private struct NoteCard: View {
    let note: SessionNote
    let store: ConferenceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let offset = note.offsetFromStart {
                    Text(SessionProgress.offsetLabel(offset))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(store.theme.accentColor)
                }
                if note.isTakeaway {
                    Text("Takeaway")
                        .font(.caption.weight(.semibold))
                }
                Spacer()
                Button {
                    store.notesStore?.toggleStar(note.id)
                } label: {
                    Label("Star", systemImage: note.isStarred ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(note.isStarred ? "Remove star" : "Star note")
                Button {
                    store.notesStore?.toggleTakeaway(note.id)
                } label: {
                    Label("Takeaway", systemImage: note.isTakeaway ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.plain)
            }
            if note.kind == .photo, let url = store.notesStore?.photoURL(for: note) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Image(systemName: "photo").resizable().scaledToFit()
                    }
                }
                .frame(maxWidth: 240, maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(note.body.isEmpty ? "Slide photo" : note.body)
            }
            if !note.body.isEmpty {
                Text(note.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(note.isTakeaway ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

#if os(iOS)
struct SlideCamera: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (Data) -> Void
        let dismiss: DismissAction
        init(onImage: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.7) {
                onImage(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif

private extension View {
    /// An inline editor must not set a title: SwiftUI lets the inner title win over session detail's.
    @ViewBuilder
    func notesTitle(_ sets: Bool) -> some View {
        if sets {
            navigationTitle("Notes")
        } else {
            self
        }
    }
}
