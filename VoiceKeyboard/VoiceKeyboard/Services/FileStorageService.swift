import Foundation

final class FileStorageService {
    private let fileName = "drafts.json"
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    func loadDrafts() -> [Draft] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let drafts = try JSONDecoder().decode([Draft].self, from: data)
            return drafts
        } catch {
            print("[FileStorage] load error: \(error)")
            return []
        }
    }

    func saveAll(_ drafts: [Draft]) throws {
        let data = try JSONEncoder().encode(drafts)
        try data.write(to: fileURL, options: .atomic)
    }

    func saveDraft(_ draft: Draft) throws {
        var drafts = loadDrafts()
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }
        try saveAll(drafts)
    }
}