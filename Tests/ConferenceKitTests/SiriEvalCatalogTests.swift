import ConferenceKit
import Foundation
import Testing

@Test func siriEvalCasesCoverEveryCanonicalSkill() throws {
    let root = skillPackageRoot()
    let folders = try FileManager.default.contentsOfDirectory(
        at: root.appendingPathComponent("SiriPreview/Skills"),
        includingPropertiesForKeys: [.isDirectoryKey]
    ).filter { url in
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }.map(\.lastPathComponent).sorted()
    #expect(folders == ConferenceSiriEvalCatalog.skillNames.sorted())
    for name in ConferenceSiriEvalCatalog.skillNames {
        let rows = ConferenceSiriEvalCatalog.cases(for: name)
        #expect(!rows.isEmpty)
        #expect(rows.contains { $0.kind == .toolSelection || $0.kind == .paraphrase })
        #expect(rows.contains { $0.kind == .negative })
        #expect(rows.contains { $0.kind == .offlineFallback && $0.includeInDeviceScenario == false })
        #expect(rows.contains { $0.includeInDeviceScenario })
    }
}

@Test func siriEvalCasesHaveUniqueIDsAndRealTools() {
    let ids = ConferenceSiriEvalCatalog.cases.map(\.id)
    #expect(Set(ids).count == ids.count)
    let tools = Set(SiriCustomToolCatalog.names)
    let ordinary = Set(ConferenceSiriEvalCatalog.ordinaryIntentNames)
    var seenTools = Set<String>()
    var seenOrdinary = Set<String>()
    for row in ConferenceSiriEvalCatalog.cases {
        if let toolName = row.toolName {
            #expect(tools.contains(toolName) || ordinary.contains(toolName))
            if tools.contains(toolName) { seenTools.insert(toolName) }
            if ordinary.contains(toolName) { seenOrdinary.insert(toolName) }
        }
        for blocked in row.mustNotCall {
            #expect(tools.contains(blocked))
        }
        #expect(ConferenceSiriEvalCatalog.skillNames.contains(row.skillName))
        #expect(!row.utterance.isEmpty)
        if row.kind == .toolSelection || row.kind == .paraphrase {
            #expect(row.toolName != nil)
            #expect(tools.contains(row.toolName ?? ""))
            #expect(!row.parameterNote.isEmpty)
        }
        if row.kind == .authConfirmation {
            #expect(row.toolName != nil)
            #expect(row.responseContains != nil)
            #expect(!row.parameterNote.isEmpty)
        }
        if row.kind == .offlineFallback {
            #expect(row.includeInDeviceScenario == false)
            #expect(row.toolName == nil)
            #expect(row.responseContains == "in the app")
        }
        if row.includeInDeviceScenario {
            #expect(row.toolName != nil || row.responseContains != nil)
        }
    }
    #expect(seenTools == tools)
    #expect(seenOrdinary == ordinary)
}

@Test func deviceScenarioOmitsTheNetworkOffCases() throws {
    let offline = ConferenceSiriEvalCatalog.cases.filter { $0.kind == .offlineFallback }
    #expect(offline.count == ConferenceSiriEvalCatalog.skillNames.count)
    #expect(ConferenceSiriEvalCatalog.deviceCases.allSatisfy { $0.kind != .offlineFallback })
    let sourceURL = skillPackageRoot().appendingPathComponent("SiriPreview/Evaluations/ConferenceSiriEvaluation.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    #expect(source.contains("SiriService.run(scenario:)"))
    #expect(source.contains("SiriResponse(.contains"))
    #expect(source.contains("IntentDefinitions"))
    for name in ConferenceSiriEvalCatalog.skillNames {
        #expect(source.contains("skillName: \"\(name)\""))
    }
    for row in ConferenceSiriEvalCatalog.deviceCases {
        #expect(source.contains("named(\"\(row.id)\")"))
    }
    for row in ConferenceSiriEvalCatalog.cases where row.includeInDeviceScenario == false {
        #expect(source.contains("named(\"\(row.id)\")") == false)
    }
}

private func skillPackageRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 {
        url.deleteLastPathComponent()
    }
    return url
}
