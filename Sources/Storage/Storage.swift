import Foundation

// Placeholder para Storage: persistência de Attempt/Session/Metrics e assets
protocol StorageProvider {
    func save<T: Encodable>(_ value: T, to path: String) throws
    func load<T: Decodable>(_ type: T.Type, from path: String) throws -> T
}

struct FileStorage: StorageProvider {
    private let fm = FileManager.default
    func save<T>(_ value: T, to path: String) throws where T : Encodable {
        let data = try JSONEncoder().encode(value)
        let url = URL(fileURLWithPath: path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
    func load<T>(_ type: T.Type, from path: String) throws -> T where T : Decodable {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

