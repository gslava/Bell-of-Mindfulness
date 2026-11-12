import Foundation

enum AppVersion {
    static var label: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else { return "vdev" }
        return "v\(version)"
    }
}
