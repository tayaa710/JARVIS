import Foundation

// MARK: - DeepgramWord

public struct DeepgramWord: Codable, Equatable {
    public let word: String
    public let start: Double
    public let end: Double
    public let confidence: Double
}

// MARK: - DeepgramAlternative

public struct DeepgramAlternative: Codable, Equatable {
    public let transcript: String
    public let confidence: Double
    public let words: [DeepgramWord]?
}

// MARK: - DeepgramChannel

public struct DeepgramChannel: Codable, Equatable {
    public let alternatives: [DeepgramAlternative]
}

// MARK: - DeepgramTranscriptResponse

public struct DeepgramTranscriptResponse: Codable, Equatable {
    public let type: String
    public let channelIndex: [Int]?
    public let duration: Double?
    public let start: Double?
    public let isFinal: Bool?
    public let speechFinal: Bool?
    public let channel: DeepgramChannel?

    enum CodingKeys: String, CodingKey {
        case type
        case channelIndex = "channel_index"
        case duration
        case start
        case isFinal = "is_final"
        case speechFinal = "speech_final"
        case channel
    }
}

// MARK: - DeepgramMessage

public enum DeepgramMessage: Equatable {
    case results(DeepgramTranscriptResponse)
    case utteranceEnd
    case speechStarted
    case metadata
    case error(String)
    case unknown(String)
}

// MARK: - Internal JSON parsing helper

struct DeepgramRawMessage: Decodable {
    let type: String
    let message: String?
}

// MARK: - TTS Types

public struct DeepgramTTSVoice: Equatable {
    public let modelID: String
    public let displayName: String

    public static let `default` = DeepgramTTSVoice(modelID: "aura-2-thalia-en", displayName: "Thalia (Female)")

    public static let all: [DeepgramTTSVoice] = [
        DeepgramTTSVoice(modelID: "aura-2-thalia-en",    displayName: "Thalia (Female)"),
        DeepgramTTSVoice(modelID: "aura-2-apollo-en",    displayName: "Apollo (Male)"),
        DeepgramTTSVoice(modelID: "aura-2-andromeda-en", displayName: "Andromeda (Female)"),
        DeepgramTTSVoice(modelID: "aura-2-orion-en",     displayName: "Orion (Male)"),
        DeepgramTTSVoice(modelID: "aura-2-helena-en",    displayName: "Helena (Female)"),
        DeepgramTTSVoice(modelID: "aura-2-zeus-en",      displayName: "Zeus (Male)"),
    ]
}

public struct DeepgramTTSConfig: Equatable {
    public let model: String
    public let encoding: String
    public let sampleRate: Int

    public init(
        model: String = DeepgramTTSVoice.default.modelID,
        encoding: String = "linear16",
        sampleRate: Int = 24000
    ) {
        self.model = model
        self.encoding = encoding
        self.sampleRate = sampleRate
    }
}
