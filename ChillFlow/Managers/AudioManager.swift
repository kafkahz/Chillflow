import Foundation
import AVFoundation
import Combine

class AudioManager: ObservableObject {
    @Published var volume: Float = 0.5 {
        didSet {
            player?.volume = volume
        }
    }
    
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var currentTrack: String?
    private var isFading = false
    
    // 音频文件名称
    private let focusTracks = ["Focus-Track-01", "Focus-Track-02"]
    
    init() {
        // macOS不需要AVAudioSession设置
    }
    
    func playFocusAudio() {
        guard !isFading else { return }
        
        let trackName = focusTracks.randomElement() ?? focusTracks[0]
        
        guard let url = Bundle.main.url(forResource: trackName, withExtension: "mp3") else {
            print("Audio file not found: \(trackName)")
            // 创建一个占位音频（静音循环）
            createPlaceholderAudio()
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1 // 无限循环
            player?.volume = 0
            player?.prepareToPlay()
            player?.play()
            
            currentTrack = trackName
            fadeIn(duration: 4.0)
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func stopAudio() {
        fadeOut(duration: 4.0) {
            self.player?.stop()
            self.player = nil
            self.currentTrack = nil
        }
    }
    
    func pauseAudio() {
        fadeOut(duration: 3.0) {
            self.player?.pause()
        }
    }
    
    func resumeAudio() {
        guard player != nil else { return }
        player?.play()
        fadeIn(duration: 3.0)
    }
    
    private func fadeIn(duration: TimeInterval) {
        guard let player = player else { return }
        
        isFading = true
        fadeTimer?.invalidate()
        
        let steps = 30
        let interval = duration / Double(steps)
        let volumeStep = volume / Float(steps)
        
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let newVolume = min(self.volume, volumeStep * Float(currentStep))
            player.volume = newVolume
            
            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
                self.isFading = false
            }
        }
        
        RunLoop.current.add(fadeTimer!, forMode: .common)
    }
    
    private func fadeOut(duration: TimeInterval, completion: @escaping () -> Void) {
        guard let player = player else {
            completion()
            return
        }
        
        isFading = true
        fadeTimer?.invalidate()
        
        let initialVolume = player.volume
        let steps = 30
        let interval = duration / Double(steps)
        let volumeStep = initialVolume / Float(steps)
        
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.player else {
                timer.invalidate()
                completion()
                return
            }
            
            currentStep += 1
            let newVolume = max(0, initialVolume - volumeStep * Float(currentStep))
            player.volume = newVolume
            
            if currentStep >= steps {
                timer.invalidate()
                self.fadeTimer = nil
                self.isFading = false
                completion()
            }
        }
        
        RunLoop.current.add(fadeTimer!, forMode: .common)
    }
    
    private func createPlaceholderAudio() {
        // 创建一个静音音频作为占位符
        // 实际应用中，用户需要添加真实的音频文件
        print("Note: Please add Focus-Track-01.mp3 and Focus-Track-02.mp3 to the app bundle")
    }
    
    deinit {
        fadeTimer?.invalidate()
        player?.stop()
    }
}

