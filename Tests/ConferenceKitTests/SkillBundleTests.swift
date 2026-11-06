import Foundation
import Testing

/// Source check for the canonical Siri skill bundle.
///
/// Apple's "Orchestrating complex actions with app skills" requires one
/// `Skills.skillsbundle`, a `Skills/<name>/SKILL.md` file, and front matter of
/// `name` plus `description` only. `name` must match the folder. This test
/// checks that shape and that the demo app's copy matches the reusable examples.
/// It does not build the app and it does not show that Siri indexed the bundle.
@Test func canonicalSkillsMatchTheDemoBundle() throws {
    let root = packageRoot()
    let examples = root.appendingPathComponent("SiriPreview/Skills")
    let demo = root.appendingPathComponent("Examples/ConferenceKitDemo/ConferenceKitDemo/Skills.skillsbundle/Skills")
    let exampleSkills = try loadSkills(in: examples)
    let demoSkills = try loadSkills(in: demo)
    #expect(exampleSkills.keys.sorted() == demoSkills.keys.sorted())
    for name in exampleSkills.keys {
        #expect(exampleSkills[name] == demoSkills[name])
    }
}

@Test func skillFrontMatterFollowsTheBundleRules() throws {
    let skills = try loadSkills(in: packageRoot().appendingPathComponent("SiriPreview/Skills"))
    #expect(skills.count == 5)
    for (name, text) in skills {
        let matter = try parseFrontMatter(text)
        #expect(matter.name == name)
        #expect(validSkillName(name))
        #expect(matter.keys == ["description", "name"])
        #expect(!matter.description.isEmpty)
        #expect(!matter.description.contains("\n"))
        #expect(matter.description.count <= 1024)
        #expect(matter.body.count <= 10_000)
        #expect(matter.body.count > 400)
    }
}

/// The phrases are the workflow contract: every custom schedule, note, and
/// directory task has guidance, plus the cases where the app has to take over.
/// They are ordinary words, not Swift type names.
@Test func skillsCoverWorkflowsAndInAppFallbacks() throws {
    let skills = try loadSkills(in: packageRoot().appendingPathComponent("SiriPreview/Skills"))
    let combined = skills.values.joined(separator: "\n").lowercased()
    let required = [
        "what's next",
        "find a session",
        "favorite",
        "add a note",
        "create a session note",
        "show the notes",
        "export notes",
        "attendee",
        "speaker",
        "directory",
        "do not invent",
        "cancel",
        "unlocked",
        "confirm",
        "this device",
        "in the app",
        "connection",
        "optional"
    ]
    for phrase in required {
        #expect(combined.contains(phrase))
    }
}

@Test func demoProjectCopiesTheSkillsBundleAsAResource() throws {
    let project = try String(contentsOf: packageRoot().appendingPathComponent("Examples/ConferenceKitDemo/project.yml"), encoding: .utf8)
    #expect(project.contains("ConferenceKitDemo/Skills.skillsbundle"))
    #expect(project.contains("buildPhase: resources"))
}

private struct SkillMatter {
    var keys: [String]
    var name: String
    var description: String
    var body: String
}

private func packageRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 {
        url.deleteLastPathComponent()
    }
    return url
}

private struct SkillBundleError: Error, CustomStringConvertible {
    var description: String
}

private func loadSkills(in directory: URL) throws -> [String: String] {
    let children = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isDirectoryKey]
    )
    var skills: [String: String] = [:]
    for child in children {
        let isDirectory = try child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        guard isDirectory else { continue }
        let files = try FileManager.default.contentsOfDirectory(at: child, includingPropertiesForKeys: nil)
        let names = files.map(\.lastPathComponent).sorted()
        guard names == ["SKILL.md"] else {
            throw SkillBundleError(description: "\(child.lastPathComponent) should contain only SKILL.md, found \(names)")
        }
        let text = try String(contentsOf: child.appendingPathComponent("SKILL.md"), encoding: .utf8)
        skills[child.lastPathComponent] = text
    }
    guard !skills.isEmpty else {
        throw SkillBundleError(description: "No skills in \(directory.path)")
    }
    return skills
}

private func parseFrontMatter(_ text: String) throws -> SkillMatter {
    let parts = text.components(separatedBy: "\n---\n")
    guard text.hasPrefix("---\n"), parts.count >= 2 else {
        throw SkillBundleError(description: "Skill is missing front matter.")
    }
    let header = parts[0].replacingOccurrences(of: "---\n", with: "")
    let body = parts.dropFirst().joined(separator: "\n---\n")
    var keys: [String] = []
    var name = ""
    var description = ""
    for line in header.split(separator: "\n", omittingEmptySubsequences: false) {
        let row = String(line)
        guard !row.isEmpty else { continue }
        let pieces = row.split(separator: ":", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else {
            throw SkillBundleError(description: "Front matter line is not key: value: \(row)")
        }
        let key = pieces[0].trimmingCharacters(in: .whitespaces)
        let value = pieces[1].trimmingCharacters(in: .whitespaces)
        keys.append(key)
        if key == "name" { name = value }
        if key == "description" { description = value }
    }
    return SkillMatter(keys: keys.sorted(), name: name, description: description, body: body)
}

private func validSkillName(_ name: String) -> Bool {
    guard (1...64).contains(name.count) else { return false }
    guard !name.hasPrefix("-"), !name.hasSuffix("-"), !name.contains("--") else { return false }
    return name.allSatisfy { $0.isLetter && $0.isLowercase || $0.isNumber || $0 == "-" }
}
