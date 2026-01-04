import Foundation
import Combine
import SwiftUI

/// Controls smooth continuous scroll with pixel-perfect animation
class ScrollController: ObservableObject {
    
    /// Current scroll offset in pixels (animated smoothly)
    @Published var scrollOffset: CGFloat = 0
    
    @Published var isPaused: Bool = true // Start paused
    @Published var scrollSpeed: Double = 10 // pixels per second (default 10 for ultra-smooth reading)
    
    /// Highlighted line index (for flash animation on click)
    @Published var highlightedLine: Int? = nil
    
    /// Track if user manually paused (vs hover-pause)
    var wasManuallyPaused: Bool = false
    
    /// Voice mode: scroll only when speaking
    @Published var voiceModeEnabled: Bool = false
    
    /// Total content height (set by view)
    var contentHeight: CGFloat = 1000
    
    /// Visible height (set by view)
    var visibleHeight: CGFloat = 150
    
    /// Line height for calculations
    let lineHeight: CGFloat = 28
    
    private var autoResumeWorkItem: DispatchWorkItem?
    
    /// Audio monitor for voice mode
    var audioMonitor: AudioLevelMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var scrollTimer: Timer?
    private var lastUpdateTime: Date = Date()
    
    init() {
        startScrollTimer()
    }
    
    deinit {
        scrollTimer?.invalidate()
        autoResumeWorkItem?.cancel()
        audioMonitor?.stop()
    }
    
    // MARK: - Voice Mode
    
    func enableVoiceMode() {
        if audioMonitor == nil {
            audioMonitor = AudioLevelMonitor()
        }
        
        // Subscribe to isSpeaking changes
        audioMonitor?.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSpeaking in
                guard let self = self, self.voiceModeEnabled else { return }
                
                // Respect manual pause — ignore voice input until user manually resumes
                if self.wasManuallyPaused { return }
                
                // In voice mode: scroll when speaking, pause when silent
                self.isPaused = !isSpeaking
            }
            .store(in: &cancellables)
        
        voiceModeEnabled = true
        audioMonitor?.start()
    }
    
    func disableVoiceMode() {
        voiceModeEnabled = false
        audioMonitor?.stop()
        cancellables.removeAll()
    }
    
    // MARK: - Scroll Timer (High frequency for smooth updates)
    
    private func startScrollTimer() {
        scrollTimer?.invalidate()
        lastUpdateTime = Date()
        
        // 60fps timer - SwiftUI will interpolate smoothly
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }
    
    @AppStorage("endBehavior") private var endBehavior: Int = 0
    var onEndReached: (() -> Void)?

    private func tick() {
        guard !isPaused else {
            lastUpdateTime = Date()
            return
        }
        
        let now = Date()
        let dt = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now
        
        // Smooth increment
        let increment = CGFloat(scrollSpeed) * CGFloat(dt)
        scrollOffset += increment
        
        // Clamp to content bounds
        let maxOffset = max(0, contentHeight - visibleHeight)
        if scrollOffset >= maxOffset {
            switch endBehavior {
            case 1: // Start Over
                scrollOffset = 0
            case 2: // Play Next
                isPaused = true
                onEndReached?()
            default: // Do Nothing (Stay at end)
                scrollOffset = maxOffset
                isPaused = true
            }
        }
        if scrollOffset < 0 {
            scrollOffset = 0
        }
    }
    
    // MARK: - Controls
    
    func pause() {
        isPaused = true
        autoResumeWorkItem?.cancel()
    }
    
    /// Pause triggered by user action (button/hotkey)
    func manualPause() {
        wasManuallyPaused = true
        pause()
    }
    
    func resume() {
        isPaused = false
        wasManuallyPaused = false
        lastUpdateTime = Date()
    }
    
    func togglePause() {
        if isPaused {
            resume()
        } else {
            manualPause()
        }
    }
    
    func reset() {
        scrollOffset = 0
        isPaused = true
        highlightedLine = nil
        autoResumeWorkItem?.cancel()
    }
    
    func adjustSpeed(delta: Double) {
        scrollSpeed = max(5, min(150, scrollSpeed + delta))
    }
    
    /// Jump to line with flash highlight and auto-resume after delay
    func jumpToLine(_ lineIndex: Int, autoResumeAfter: TimeInterval = 1.0) {
        let wasPlaying = !isPaused
        
        // Jump to the line
        scrollOffset = max(0, CGFloat(lineIndex) * lineHeight)
        lastUpdateTime = Date()
        
        // Flash highlight
        highlightedLine = lineIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.highlightedLine = nil
        }
        
        // If was playing, pause briefly then auto-resume
        if wasPlaying {
            isPaused = true
            
            autoResumeWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.resume()
            }
            autoResumeWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + autoResumeAfter, execute: workItem)
        }
    }
    
    /// Scroll by delta (for mouse wheel)
    func scrollByDelta(_ delta: CGFloat) {
        scrollOffset = max(0, scrollOffset - delta)
        
        // Clamp
        let maxOffset = max(0, contentHeight - visibleHeight)
        scrollOffset = min(scrollOffset, maxOffset)
    }
    
    /// Jump to specific pixel offset (legacy)
    func goToOffset(_ offset: CGFloat) {
        scrollOffset = max(0, offset)
        lastUpdateTime = Date()
    }
    
    /// Current line index based on offset
    var currentLineIndex: Int {
        Int(scrollOffset / lineHeight)
    }
}
