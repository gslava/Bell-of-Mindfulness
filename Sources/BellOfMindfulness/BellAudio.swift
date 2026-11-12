import AVFoundation
import Foundation

@MainActor
final class BellAudio: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var onChange: ((Bool) -> Void)?
    var onFailure: ((Error) -> Void)?
    var isPlaying: Bool { player?.isPlaying == true }

    func play(volume: Double) throws {
        stop()
        guard let url = Bundle.main.url(forResource: "Bell of Mindfulness", withExtension: "mp3") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.delegate = self
        newPlayer.volume = Float(volume)
        newPlayer.numberOfLoops = 0
        guard newPlayer.prepareToPlay(), newPlayer.play() else { throw CocoaError(.fileReadUnknown) }
        player = newPlayer
        onChange?(true)
    }

    func setVolume(_ value: Double) { player?.volume = Float(value) }

    func stop() {
        guard player != nil else { return }
        player?.stop()
        player = nil // Release the decoder and audio buffers while idle.
        onChange?(false)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let identity = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, self.player.map(ObjectIdentifier.init) == identity else { return }
            self.stop()
            if !flag { self.onFailure?(CocoaError(.fileReadUnknown)) }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let identity = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, self.player.map(ObjectIdentifier.init) == identity else { return }
            self.stop()
            self.onFailure?(error ?? CocoaError(.fileReadCorruptFile))
        }
    }
}
