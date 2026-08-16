import Foundation
#if canImport(JavaScriptCore)
@preconcurrency import JavaScriptCore
import OSLog

/// Runs YouTube's current player transformations inside JavaScriptCore.
///
/// The AST helper resources are the MIT-licensed solver already used by the
/// project's former YouTubeKit dependency. Keeping this type private to the
/// URL-signing actor lets the app retain its own transport and client policy.
nonisolated final class YouTubeSignatureSolver {
    enum SolverError: LocalizedError {
        case contextCreationFailed
        case resourceNotFound(String)
        case evaluationFailed
        case resultConversionFailed
        case encodingFailed
        case decodingFailed(Error)
        case challengeFailed(type: String, message: String)

        var errorDescription: String? {
            switch self {
            case .contextCreationFailed:
                "Could not create the JavaScript signing context."
            case .resourceNotFound(let name):
                "The YouTube signing resource \(name) is missing."
            case .evaluationFailed:
                "The YouTube signing script could not be evaluated."
            case .resultConversionFailed:
                "The YouTube signing result was invalid."
            case .encodingFailed:
                "The YouTube signing request could not be encoded."
            case .decodingFailed(let error):
                "The YouTube signing result could not be decoded: \(error.localizedDescription)"
            case .challengeFailed(let type, let message):
                "The YouTube \(type) challenge failed: \(message)"
            }
        }
    }

    struct SolveRequest {
        let nInputs: [String]
        let signatureInputs: [String]
    }

    struct SolveResponse {
        let nValues: [String: String]
        let signatureValues: [String: String]
    }

    private struct Request: Codable {
        let type: RequestType
        let challenges: [String]

        enum RequestType: String, Codable {
            case n
            case signature = "sig"
        }
    }

    private struct Input: Codable {
        let type: PlayerType
        let player: String?
        let preprocessedPlayer: String?
        let requests: [Request]
        let outputPreprocessed: Bool

        enum CodingKeys: String, CodingKey {
            case type
            case player
            case preprocessedPlayer = "preprocessed_player"
            case requests
            case outputPreprocessed = "output_preprocessed"
        }

        enum PlayerType: String, Codable {
            case player
            case preprocessedPlayer = "preprocessed_player"
        }
    }

    private struct Response: Codable {
        struct Item: Codable {
            let type: ItemType
            let data: [String: String]?
            let error: String?

            enum ItemType: String, Codable {
                case result
                case error
            }
        }

        let responses: [Item]
        let preprocessedPlayer: String?

        enum CodingKeys: String, CodingKey {
            case responses
            case preprocessedPlayer = "preprocessed_player"
        }
    }

    private static let logger = Logger(
        subsystem: "com.SilverMarcs.SwiftTube",
        category: "YouTubeSignatureSolver"
    )

    private let context: JSContext
    private let playerJavaScript: String
    private var preprocessedPlayer: String?

    init(playerJavaScript: String) throws {
        self.playerJavaScript = playerJavaScript
        guard let context = JSContext(virtualMachine: JSVirtualMachine()) else {
            throw SolverError.contextCreationFailed
        }
        self.context = context
        context.exceptionHandler = { _, exception in
            Self.logger.error("JavaScript signing error: \(exception?.toString() ?? "unknown", privacy: .public)")
        }

        context.evaluateScript(
            #"""
            globalThis.XMLHttpRequest = { prototype: {} };
            globalThis.URL = class URL {
                constructor(url) {
                    this.href = url;
                    const match = url.match(/^(https?:)\/\/([^/:]+)(:(\d+))?(\/[^?#]*)?(\?[^#]*)?(#.*)?$/);
                    this.protocol = match ? match[1] : '';
                    this.hostname = match ? match[2] : '';
                    this.port = match && match[4] ? match[4] : '';
                    this.pathname = match && match[5] ? match[5] : '/';
                    this.search = match && match[6] ? match[6] : '';
                    this.hash = match && match[7] ? match[7] : '';
                }
            };
            globalThis.navigator = {
                userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            };
            const window = Object.assign(Object.create(null), globalThis);
            window.location = new URL("https://www.youtube.com/watch?v=cathode");
            const document = {};
            let self = globalThis;
            """#
        )

        try evaluateResource(named: "meriyah", extension: "umd.js")
        try evaluateResource(named: "astring", extension: "umd.js")
        try evaluateResource(named: "yt_ejs_helper", extension: "js")
    }

    func solve(_ request: SolveRequest) throws -> SolveResponse {
        let requests = [
            Request(type: .n, challenges: request.nInputs),
            Request(type: .signature, challenges: request.signatureInputs),
        ]
        let input: Input
        if let preprocessedPlayer {
            input = Input(
                type: .preprocessedPlayer,
                player: nil,
                preprocessedPlayer: preprocessedPlayer,
                requests: requests,
                outputPreprocessed: false
            )
        } else {
            input = Input(
                type: .player,
                player: playerJavaScript,
                preprocessedPlayer: nil,
                requests: requests,
                outputPreprocessed: true
            )
        }

        let response = try evaluate(input)
        if preprocessedPlayer == nil {
            preprocessedPlayer = response.preprocessedPlayer
        }

        var nValues: [String: String] = [:]
        var signatureValues: [String: String] = [:]
        for (request, item) in zip(requests, response.responses) {
            switch item.type {
            case .error:
                throw SolverError.challengeFailed(
                    type: request.type.rawValue,
                    message: item.error ?? "unknown error"
                )
            case .result:
                guard let values = item.data else { continue }
                switch request.type {
                case .n:
                    nValues.merge(values) { _, new in new }
                case .signature:
                    signatureValues.merge(values) { _, new in new }
                }
            }
        }
        return SolveResponse(nValues: nValues, signatureValues: signatureValues)
    }

    private func evaluateResource(named name: String, extension fileExtension: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            throw SolverError.resourceNotFound("\(name).\(fileExtension)")
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        context.evaluateScript(source)
    }

    private func evaluate(_ input: Input) throws -> Response {
        let encoded = try JSONEncoder().encode(input)
        guard let json = String(data: encoded, encoding: .utf8) else {
            throw SolverError.encodingFailed
        }
        context.setObject(json, forKeyedSubscript: "cathodeSigningInput" as NSString)
        guard let result = context.evaluateScript(
            "JSON.stringify(jsc(JSON.parse(cathodeSigningInput)))"
        ) else {
            throw SolverError.evaluationFailed
        }
        guard let output = result.toString() else {
            throw SolverError.resultConversionFailed
        }
        guard let data = output.data(using: .utf8) else {
            throw SolverError.encodingFailed
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            Self.logger.error("Invalid signing response: \(output, privacy: .private(mask: .hash))")
            throw SolverError.decodingFailed(error)
        }
    }
}
#endif
