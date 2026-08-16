import Foundation

actor YouTubePlayerURLSigner {
    struct Challenge: Sendable {
        let url: URL
        let signature: String?
        let signatureParameter: String?

        init(url: URL, signature: String? = nil, signatureParameter: String? = nil) {
            self.url = url
            self.signature = signature
            self.signatureParameter = signatureParameter
        }
    }

    enum SigningError: LocalizedError {
        case unsupportedPlatform
        case invalidPlayerResponse
        case missingSolution

        var errorDescription: String? {
            switch self {
            case .unsupportedPlatform:
                "YouTube URL signing is unavailable on this platform."
            case .invalidPlayerResponse:
                "YouTube returned an invalid player script."
            case .missingSolution:
                "YouTube did not return a valid URL transformation."
            }
        }
    }

    private let session: URLSession
    private var cachedPlayerURL: URL?
#if canImport(JavaScriptCore)
    private var cachedSolver: YouTubeSignatureSolver?
#endif

    init(session: URLSession = YouTubeMediaTransport.session) {
        self.session = session
    }

    func resolve(
        _ challenges: [Challenge],
        playerJavaScriptURL: URL
    ) async throws -> [URL] {
        guard !challenges.isEmpty else { return [] }
#if canImport(JavaScriptCore)
        let solver = try await solver(for: playerJavaScriptURL)
        let nInputs = challenges.compactMap { Self.nChallenge(in: $0.url) }
        let signatureInputs = challenges.compactMap(\.signature)
        let response = try solver.solve(.init(
            nInputs: Array(Set(nInputs)),
            signatureInputs: Array(Set(signatureInputs))
        ))

        return try challenges.map { challenge in
            guard var components = URLComponents(
                url: challenge.url,
                resolvingAgainstBaseURL: false
            ) else {
                throw SigningError.invalidPlayerResponse
            }
            var queryItems = components.queryItems ?? []
            if let initialN = Self.nChallenge(in: challenge.url) {
                guard let solvedN = response.nValues[initialN], !solvedN.isEmpty else {
                    throw SigningError.missingSolution
                }
                if let nIndex = queryItems.firstIndex(where: { $0.name == "n" }) {
                    queryItems[nIndex].value = solvedN
                } else {
                    components.path = components.path.replacing(
                        "/n/\(initialN)",
                        with: "/n/\(solvedN)"
                    )
                }
            }
            if let signature = challenge.signature {
                guard let solvedSignature = response.signatureValues[signature],
                      !solvedSignature.isEmpty
                else {
                    throw SigningError.missingSolution
                }
                let parameter = challenge.signatureParameter ?? "signature"
                queryItems.removeAll { $0.name == parameter }
                queryItems.append(URLQueryItem(name: parameter, value: solvedSignature))
            }
            components.queryItems = queryItems
            guard let url = components.url else {
                throw SigningError.invalidPlayerResponse
            }
            return url
        }
#else
        throw SigningError.unsupportedPlatform
#endif
    }

    private static func nChallenge(in url: URL) -> String? {
        if let queryValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "n" })?
            .value {
            return queryValue
        }
        let pathComponents = url.pathComponents
        guard let nIndex = pathComponents.firstIndex(of: "n"),
              pathComponents.indices.contains(pathComponents.index(after: nIndex))
        else { return nil }
        return pathComponents[pathComponents.index(after: nIndex)]
    }

#if canImport(JavaScriptCore)
    private func solver(for playerJavaScriptURL: URL) async throws -> YouTubeSignatureSolver {
        if cachedPlayerURL == playerJavaScriptURL, let cachedSolver {
            return cachedSolver
        }
        var request = URLRequest(url: playerJavaScriptURL)
        request.httpShouldHandleCookies = false
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let javaScript = String(data: data, encoding: .utf8),
              !javaScript.isEmpty
        else {
            throw SigningError.invalidPlayerResponse
        }
        let solver = try YouTubeSignatureSolver(playerJavaScript: javaScript)
        cachedPlayerURL = playerJavaScriptURL
        cachedSolver = solver
        return solver
    }
#endif
}
