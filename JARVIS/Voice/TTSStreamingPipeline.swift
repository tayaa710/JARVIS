import Foundation

// MARK: - TTSStreamingPipeline

/// Manages the TTS streaming pipeline: accepts text fragments from the orchestrator,
/// sanitizes them, synthesizes audio (with 1-ahead prefetch), and plays them back.
/// Extracted from ChatViewModel to keep it under 500 lines.
@MainActor
final class TTSStreamingPipeline {

    // MARK: - Callbacks

    /// Called when TTS becomes active or inactive (for wake word pause/resume).
    var onTTSActiveChanged: ((Bool) -> Void)?

    /// Called when TTS finishes and response is complete (to set status = .idle).
    var onFinished: (() -> Void)?

    // MARK: - State

    private(set) var isRunning: Bool = false
    private var pendingSentences: [String] = []
    private var responseIsComplete: Bool = false
    private var fetchTask: Task<Void, Never>?
    private var playTask: Task<Void, Never>?

    // MARK: - Dependencies

    private var speechOutput: (any SpeechOutputProviding)?

    // MARK: - Init

    init() {}

    // MARK: - Public API

    /// Set the speech output provider. Called lazily when TTS is first needed.
    func setSpeechOutput(_ output: any SpeechOutputProviding) {
        self.speechOutput = output
    }

    /// Reset state for a new response.
    func reset() {
        pendingSentences.removeAll()
        responseIsComplete = false
    }

    /// Add sanitized text fragments to the queue and start the pipeline if needed.
    func enqueueSentences(_ sentences: [String]) {
        pendingSentences.append(contentsOf: sentences)
        startIfNeeded()
    }

    /// Mark the response as complete and flush remaining buffer text.
    func markComplete(remainingText: String) {
        responseIsComplete = true
        if !remainingText.isEmpty {
            pendingSentences.append(remainingText)
        }
        if pendingSentences.isEmpty && !isRunning {
            onFinished?()
        } else {
            startIfNeeded()
        }
    }

    /// Returns true if the pipeline has no more work and the response is done.
    var isFinished: Bool {
        responseIsComplete && pendingSentences.isEmpty && !isRunning
    }

    /// Stop all TTS activity immediately.
    func stop() async {
        fetchTask?.cancel()
        playTask?.cancel()
        fetchTask = nil
        playTask = nil
        pendingSentences.removeAll()
        isRunning = false

        // Tear down persistent audio engine if available
        if let router = speechOutput as? SpeechOutputRouter,
           let audioOutProviding = router.audioOutputForPipeline,
           let audioOut = audioOutProviding as? AVAudioEngineOutput {
            audioOut.teardownEngine()
        }
        await speechOutput?.stop()
        onTTSActiveChanged?(false)
    }

    // MARK: - Private

    private func startIfNeeded() {
        guard !isRunning, !pendingSentences.isEmpty, speechOutput != nil else { return }

        isRunning = true
        onTTSActiveChanged?(true)

        // Try prefetch pipeline (Deepgram with persistent engine)
        if let router = speechOutput as? SpeechOutputRouter,
           let deepgram = router.deepgramBackend,
           let audioOutProviding = router.audioOutputForPipeline,
           let audioOut = audioOutProviding as? AVAudioEngineOutput {
            startPrefetchMode(deepgram: deepgram, audioOutput: audioOut)
        } else {
            startSimpleMode()
        }
    }

    /// Prefetch mode: fetch audio for next sentence while current one plays.
    private func startPrefetchMode(deepgram: DeepgramSpeechOutput, audioOutput: AVAudioEngineOutput) {
        try? audioOutput.prepareEngine(sampleRate: 24000, channelCount: 1)

        playTask = Task { [weak self] in
            guard let self else { return }

            var prefetchTask: Task<Data?, Never>?

            while true {
                guard !Task.isCancelled else { break }

                if pendingSentences.isEmpty {
                    if responseIsComplete { break }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    continue
                }

                let sentence = pendingSentences.removeFirst()

                // Start prefetching the NEXT sentence immediately
                if let nextSentence = pendingSentences.first {
                    let dg = deepgram
                    prefetchTask = Task { try? await dg.synthesizeAudio(text: nextSentence) }
                }

                // Fetch + play current sentence
                if let audioData = try? await deepgram.synthesizeAudio(text: sentence) {
                    try? await audioOutput.play(pcmData: audioData, sampleRate: 24000, channelCount: 1)
                }

                // Use prefetched result if available
                if let task = prefetchTask, !pendingSentences.isEmpty {
                    if let data = await task.value {
                        _ = pendingSentences.removeFirst() // consumed by prefetch

                        // Prefetch the one after that
                        if let afterNext = pendingSentences.first {
                            let dg = deepgram
                            prefetchTask = Task { try? await dg.synthesizeAudio(text: afterNext) }
                        } else {
                            prefetchTask = nil
                        }

                        try? await audioOutput.play(pcmData: data, sampleRate: 24000, channelCount: 1)
                    } else {
                        prefetchTask = nil
                    }
                }
            }

            audioOutput.teardownEngine()
            isRunning = false
            onTTSActiveChanged?(false)
            if responseIsComplete { onFinished?() }
        }
    }

    /// Simple sequential mode: used for Apple TTS or mock (no prefetch).
    private func startSimpleMode() {
        playTask = Task { [weak self] in
            guard let self, let output = speechOutput else { return }

            while true {
                guard !Task.isCancelled else { break }

                if pendingSentences.isEmpty {
                    if responseIsComplete { break }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continue
                }

                let sentence = pendingSentences.removeFirst()
                do {
                    try await output.speak(text: sentence)
                } catch {
                    Logger.tts.error("TTS sentence failed: \(error.localizedDescription)")
                }
            }

            isRunning = false
            onTTSActiveChanged?(false)
            if responseIsComplete { onFinished?() }
        }
    }

    // MARK: - Fragment Extraction

    /// Extracts speakable fragments from the buffer. Breaks on sentence terminators,
    /// newlines, and long clauses to reduce time-to-first-speech.
    static func extractSpeakableFragments(from buffer: inout String) -> [String] {
        var fragments: [String] = []
        let chars = Array(buffer)
        let sentenceTerminators: Set<Character> = [".", "!", "?"]
        var searchFrom = 0
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            // Break on sentence terminators (. ! ?) followed by whitespace
            if sentenceTerminators.contains(ch) {
                let nextIdx = i + 1
                if nextIdx < chars.count && (chars[nextIdx] == " " || chars[nextIdx] == "\n") {
                    let fragment = String(chars[searchFrom...i]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fragment.isEmpty { fragments.append(fragment) }
                    var skip = nextIdx
                    while skip < chars.count && (chars[skip] == " " || chars[skip] == "\n") { skip += 1 }
                    searchFrom = skip
                    i = skip
                    continue
                }
            }

            // Break on newlines (paragraph boundaries) — only if we have some content
            if ch == "\n" && (i - searchFrom) > 10 {
                let fragment = String(chars[searchFrom...i]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !fragment.isEmpty { fragments.append(fragment) }
                var skip = i + 1
                while skip < chars.count && (chars[skip] == " " || chars[skip] == "\n") { skip += 1 }
                searchFrom = skip
                i = skip
                continue
            }

            // Break on colons/semicolons if clause is long enough (>40 chars)
            if (ch == ":" || ch == ";") && (i - searchFrom) > 40 {
                let nextIdx = i + 1
                if nextIdx < chars.count && chars[nextIdx] == " " {
                    let fragment = String(chars[searchFrom...i]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fragment.isEmpty { fragments.append(fragment) }
                    searchFrom = nextIdx + 1
                    i = nextIdx + 1
                    continue
                }
            }

            i += 1
        }

        buffer = String(chars[searchFrom...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return fragments
    }
}
