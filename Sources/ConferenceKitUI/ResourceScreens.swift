import ConferenceKit
import SwiftUI
#if os(iOS) || os(visionOS)
import QuickLook
import UIKit
#endif
#if os(macOS)
import AppKit
import QuickLookUI
#endif

struct ResourceListScreen: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool
    @State private var selectedID: String?
    @State private var preview: PreviewFile?

    private var groups: [ResourceGroup] {
        ResourceTransfer.grouped(store.resources)
    }

    var body: some View {
        Group {
            if groups.isEmpty {
                EmptyPane(title: "Resources", systemImage: "doc", message: "No documents yet.")
            } else {
                #if os(tvOS)
                resourceCards
                #elseif os(macOS) || os(visionOS)
                resourceColumn
                #else
                resourceList
                #endif
            }
        }
        .navigationTitle("Resources")
        .sheet(item: $preview) { file in
            ResourcePreview(url: file.url)
        }
    }

    private var resourceList: some View {
        List {
            ForEach(groups) { group in
                Section(group.label) {
                    ForEach(group.resources) { resource in
                        Button {
                            router.open(.resource(resource.id), push: push)
                        } label: {
                            ResourceRow(resource: resource, store: store)
                        }
                        .buttonStyle(.plain)
                        .siriEntity(.resource(resource.id))
                    }
                }
            }
        }
    }

    #if os(macOS) || os(visionOS)
    private var resourceColumn: some View {
        HStack(spacing: 0) {
            List {
                ForEach(groups) { group in
                    Section(group.label) {
                        ForEach(group.resources) { resource in
                            Button {
                                selectedID = resource.id
                            } label: {
                                ResourceRow(resource: resource, store: store)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selectedID == resource.id ? Color.accentColor.opacity(0.18) : Color.clear)
                            .siriEntity(.resource(resource.id))
                        }
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 320, maxWidth: 420)
            Divider()
            ResourceDetail(store: store, resource: selected, preview: $preview)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedID == nil { selectedID = groups.first?.resources.first?.id }
        }
    }

    private var selected: ConferenceResource? {
        let id = selectedID ?? groups.first?.resources.first?.id
        return store.resources.first { $0.id == id }
    }
    #endif

    #if os(tvOS)
    private var resourceCards: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                ForEach(groups) { group in
                    Text(group.label).font(.title2.bold()).padding(.horizontal, 48)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 420), spacing: 32)], spacing: 32) {
                        ForEach(group.resources) { resource in
                            Button {
                                router.open(.resource(resource.id), push: true)
                            } label: {
                                ResourceRow(resource: resource, store: store)
                                    .padding(24)
                                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.horizontal, 48)
                }
            }
            .padding(.vertical, 40)
        }
    }
    #endif
}

struct ResourceRow: View {
    let resource: ConferenceResource
    let store: ConferenceStore

    var body: some View {
        let record = store.resourceLibrary?.record(for: resource) ?? ResourceTransfer.initial(id: resource.id)
        VStack(alignment: .leading, spacing: 6) {
            Label(resource.title, systemImage: resource.kind.systemImage)
                .font(.headline)
            HStack {
                Text(resource.kind.label)
                if let size = resource.fileSizeLabel {
                    Text(size)
                }
                Text(status(record))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if record.phase == .downloading {
                ProgressView(value: record.progress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func status(_ record: ResourceDownloadRecord) -> String {
        switch record.phase {
        case .idle: resource.kind == .link ? "Opens in the browser" : "Not downloaded"
        case .downloading: "Downloading"
        case .downloaded: "On this device"
        case .failed: record.message ?? "Couldn’t download"
        }
    }
}

struct ResourceDetailScreen: View {
    @Bindable var store: ConferenceStore
    var resource: ConferenceResource?
    @State private var preview: PreviewFile?

    var body: some View {
        ResourceDetail(store: store, resource: resource, preview: $preview)
            .sheet(item: $preview) { file in
                ResourcePreview(url: file.url)
            }
            .navigationTitle(resource?.title ?? "Resource")
    }
}

struct ResourceDetail: View {
    @Bindable var store: ConferenceStore
    let resource: ConferenceResource?
    @Binding var preview: PreviewFile?
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let resource {
            let library = store.resourceLibrary
            let record = library?.record(for: resource) ?? ResourceTransfer.initial(id: resource.id)
            let action = ResourceTransfer.action(
                for: resource,
                record: record,
                directory: library?.directory ?? URL(fileURLWithPath: NSTemporaryDirectory())
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(resource.title, systemImage: resource.kind.systemImage)
                        .font(.title2.weight(.semibold))
                    LabeledContent("Kind", value: resource.kind.label)
                    LabeledContent("Category", value: ResourceTransfer.categoryLabel(resource.category))
                    if let size = resource.fileSizeLabel {
                        LabeledContent("Size", value: size)
                    }
                    switch action {
                    case .browser(let url):
                        Button {
                            openURL(url)
                        } label: {
                            Label("Open in browser", systemImage: "safari")
                        }
                    case .download:
                        Button {
                            library?.download(resource)
                        } label: {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                        .disabled(library == nil)
                    case .downloading(let progress):
                        ProgressView(value: progress) {
                            Text("Downloading")
                        }
                    case .preview(let url):
                        previewControl(url)
                    case .failed(let message):
                        Text(message).foregroundStyle(.secondary)
                        Button("Try again") { library?.download(resource) }
                            .disabled(library == nil)
                    }
                    #if os(macOS)
                    if case .preview(let url) = action {
                        MacQuickLook(url: url)
                            .frame(minHeight: 360)
                    }
                    #endif
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            EmptyPane(title: "Resources", systemImage: "doc", message: "Choose a document.")
        }
    }

    @ViewBuilder
    private func previewControl(_ url: URL) -> some View {
        #if os(iOS) || os(visionOS) || os(macOS)
        Button {
            preview = PreviewFile(url: url)
        } label: {
            Label("Preview", systemImage: "eye")
        }
        #else
        Text("Saved on this device.")
            .foregroundStyle(.secondary)
        #endif
    }
}

struct PreviewFile: Identifiable, Hashable {
    var url: URL
    var id: String { url.path }
}

struct ResourcePreview: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            #if os(iOS) || os(visionOS)
            QuickLookPreview(url: url)
                .navigationTitle(url.lastPathComponent)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            #elseif os(macOS)
            MacQuickLook(url: url)
                .frame(minWidth: 640, minHeight: 480)
                .navigationTitle(url.lastPathComponent)
            #else
            Text(url.lastPathComponent)
            #endif
        }
    }
}

#if os(iOS) || os(visionOS)
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#endif

#if os(macOS)
struct MacQuickLook: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> MacPreviewHost {
        MacPreviewHost(url: url)
    }

    func updateNSView(_ view: MacPreviewHost, context: Context) {
        view.update(url: url)
    }
}

final class MacPreviewHost: NSView {
    private var preview: QLPreviewView?

    init(url: URL) {
        let frame = NSRect(x: 0, y: 0, width: 640, height: 480)
        super.init(frame: frame)
        if let preview = QLPreviewView(frame: frame, style: .normal) {
            preview.autoresizingMask = [.width, .height]
            preview.autostarts = true
            preview.previewItem = url as NSURL
            addSubview(preview)
            self.preview = preview
        }
    }

    required init?(coder: NSCoder) { nil }

    func update(url: URL) {
        preview?.previewItem = url as NSURL
        preview?.refreshPreviewItem()
    }
}
#endif
