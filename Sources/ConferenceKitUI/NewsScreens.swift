import ConferenceKit
import SwiftUI

struct NewsFeedScreen: View {
    @Bindable var store: ConferenceStore
    var router: ConferenceRouter
    var push: Bool
    @State private var selectedID: String?

    var body: some View {
        Group {
            if store.newsItems.isEmpty {
                EmptyPane(title: "News", systemImage: "newspaper", message: "No announcements yet.")
            } else {
                #if os(tvOS)
                newsCards
                #elseif os(macOS) || os(visionOS)
                newsColumn
                #else
                newsList
                #endif
            }
        }
        .navigationTitle("News")
    }

    private var newsList: some View {
        List(store.newsItems) { item in
            Button {
                router.open(.newsItem(item.id), push: push)
            } label: {
                NewsRow(item: item)
            }
            .buttonStyle(.plain)
            .siriEntity(.news(item.id))
        }
    }

    #if os(macOS) || os(visionOS)
    private var newsColumn: some View {
        HStack(spacing: 0) {
            List(store.newsItems) { item in
                Button {
                    selectedID = item.id
                } label: {
                    NewsRow(item: item)
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedID == item.id ? Color.accentColor.opacity(0.18) : Color.clear)
                .siriEntity(.news(item.id))
            }
            .frame(minWidth: 240, idealWidth: 300, maxWidth: 380)
            Divider()
            NewsDetail(item: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedID == nil { selectedID = store.newsItems.first?.id }
        }
    }
    #endif

    #if os(tvOS)
    private var newsCards: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 520), spacing: 40)], spacing: 40) {
                ForEach(store.newsItems) { item in
                    Button {
                        router.open(.newsItem(item.id), push: true)
                    } label: {
                        NewsRow(item: item)
                            .padding(28)
                            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(48)
        }
    }
    #endif

    #if os(macOS) || os(visionOS)
    private var selected: ConferenceNewsItem? {
        let id = selectedID ?? store.newsItems.first?.id
        return store.newsItems.first { $0.id == id }
    }
    #endif
}

struct NewsRow: View {
    let item: ConferenceNewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageName = item.imageName {
                Image(systemName: imageName)
                    .font(.title3)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title).font(.headline)
                    if item.isPinned {
                        Text("Pinned")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text(item.publishedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NewsDetail: View {
    let item: ConferenceNewsItem?

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let imageName = item.imageName {
                        Image(systemName: imageName)
                            .font(.largeTitle)
                            .accessibilityHidden(true)
                    }
                    if item.isPinned {
                        Text("Pinned").font(.caption.weight(.semibold))
                    }
                    Text(item.title).font(.title2.weight(.semibold))
                    Text(item.publishedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(item.body)
                    if let url = item.linkURL {
                        Link(destination: url) {
                            Label("Open link", systemImage: "link")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            EmptyPane(title: "News", systemImage: "newspaper", message: "Choose an announcement.")
        }
    }
}
