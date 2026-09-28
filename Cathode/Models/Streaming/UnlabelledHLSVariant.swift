import Foundation

/// Embedded-player masters can contain one muxed audio track with no language
/// labels. Select an HD rendition without guessing between alternative tracks.
nonisolated struct UnlabelledHLSVariant {
    let url: URL
    let height: Int
    let manifest: String

    static func select(in manifest: String, baseURL: URL, minimumHeight: Int) -> Self? {
        let lines = manifest.components(separatedBy: .newlines)
        guard !lines.contains(where: {
            $0.contains("YT-EXT-AUDIO-CONTENT-ID=")
                || ($0.hasPrefix("#EXT-X-MEDIA:") && $0.contains("TYPE=AUDIO"))
        }) else { return nil }

        var best: (url: URL, height: Int, bandwidth: Int, info: String)?
        for (index, line) in lines.enumerated() where line.hasPrefix("#EXT-X-STREAM-INF:") {
            // A referenced audio group cannot be safely stripped from a master.
            guard attribute("AUDIO", in: line) == nil,
                  let resolution = attribute("RESOLUTION", in: line),
                  let height = resolution.split(separator: "x").last.flatMap({ Int($0) }),
                  height >= minimumHeight,
                  let resource = lines.dropFirst(index + 1).first(where: { !$0.isEmpty }),
                  !resource.hasPrefix("#"),
                  let url = URL(string: resource, relativeTo: baseURL)?.absoluteURL,
                  url.scheme == "https"
            else { continue }
            let bandwidth = attribute("BANDWIDTH", in: line).flatMap(Int.init) ?? 0
            if let best, (height, bandwidth) <= (best.height, best.bandwidth) { continue }
            best = (url, height, bandwidth, line)
        }
        guard let best else { return nil }
        let globals = lines.filter {
            $0.hasPrefix("#") && !$0.hasPrefix("#EXT-X-STREAM-INF:")
                && !$0.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:")
        }
        return Self(url: best.url, height: best.height,
                    manifest: (globals + [best.info, best.url.absoluteString]).joined(separator: "\n") + "\n")
    }

    private static func attribute(_ name: String, in line: String) -> String? {
        let attributes = line.split(separator: ":", maxSplits: 1).last ?? ""
        return attributes.split(separator: ",").first { $0.hasPrefix(name + "=") }
            .map { String($0.dropFirst(name.count + 1)).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }
}
