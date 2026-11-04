import AskKit
import ConferenceKit
import ConferenceKitAskLink
import SwiftUI

/// Runs fixed questions through `ConferenceAsk.assistant` and shows each reply.
struct AskDemoView: View {
    var store: ConferenceStore
    @State private var assistant: AskAssistant?
    @State private var rows: [Row] = []
    @State private var error: String?

    struct Row: Identifiable {
        let id = UUID()
        var question: String
        var skill: String
        var usedModel: Bool
        var answer: String
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Linked") {
                    Text("ConferenceAskLink.isLinked = \(ConferenceAskLink.isLinked ? "true" : "false")")
                        .accessibilityIdentifier("ask.linked")
                    Text("answered=\(rows.count)")
                        .accessibilityIdentifier("ask.progress")
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
                Section("Answers") {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.question).font(.headline)
                            Text("skill=\(row.skill) model=\(row.usedModel ? "yes" : "no")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(row.answer)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("ask.row")
                    }
                }
            }
            .navigationTitle("Ask")
            .task { await run() }
        }
    }

    private func questions(_ manifest: ConferenceManifest) -> [String] {
        var list = ["What's next?"]
        if let speaker = manifest.speakers.first {
            list.append("When is \(speaker.name) speaking?")
        }
        if let room = manifest.rooms.first {
            list.append("What's next in \(room.name)?")
        }
        list.append("Summarize my notes from day 1")
        list.append("My schedule")
        return list
    }

    private func run() async {
        guard rows.isEmpty else { return }
        if store.manifest == nil { await store.load() }
        guard let manifest = store.manifest else {
            error = store.lastError ?? "No manifest"
            return
        }
        let source = ConferenceAskSource(
            manifest: manifest,
            notes: store.notesStore?.notes ?? [],
            favoriteSessionIDs: store.favorites.ids
        )
        do {
            let assistant = try ConferenceAsk.assistant(source: source)
            self.assistant = assistant
            for question in questions(manifest) {
                let result = await assistant.handle(utterance: question)
                let answer: String
                switch result.fulfillment {
                case .reply(let reply): answer = reply.text
                case .intent(let card): answer = "intent card: \(card)"
                }
                rows.append(Row(question: question, skill: result.skillID, usedModel: result.usedModel, answer: answer))
                print("CKDEMO ASK q=\(question) skill=\(result.skillID) model=\(result.usedModel) a=\(answer)")
            }
        } catch {
            self.error = "\(error)"
        }
    }
}
