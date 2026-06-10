import AppKit
import Foundation

/// 持久化:把当前宠物(抠图 PNG + 档案 JSON)存到 Application Support。
public struct PetStore {
    public let baseURL: URL

    public init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )[0]
            self.baseURL = support.appendingPathComponent("CatOS/current", isDirectory: true)
        }
    }

    private var profileURL: URL { baseURL.appendingPathComponent("profile.json") }

    public func save(profile: PetProfile, image: CGImage) throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let imageURL = baseURL.appendingPathComponent(profile.imageFileName)
        try ImageUtil.writePNG(image, to: imageURL)
        let data = try JSONEncoder().encode(profile)
        try data.write(to: profileURL, options: .atomic)
    }

    /// 读取已保存的宠物;文件缺失或损坏时返回 nil(回到导入流程,不崩溃)。
    public func loadCurrent() -> (profile: PetProfile, image: NSImage)? {
        guard let data = try? Data(contentsOf: profileURL),
              let profile = try? JSONDecoder().decode(PetProfile.self, from: data)
        else { return nil }
        let imageURL = baseURL.appendingPathComponent(profile.imageFileName)
        guard let image = NSImage(contentsOf: imageURL), image.isValid else { return nil }
        return (profile, image)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: baseURL)
    }
}
