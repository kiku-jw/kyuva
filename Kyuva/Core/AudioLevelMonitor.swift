import AVFoundation
import Combine
import Accelerate

/// Monitors microphone audio level for voice-activated scrolling
/// Uses simple volume detection, not speech recognition
/// Based on best practices from deep research to avoid common AVAudioEngine crashes
class AudioLevelMonitor: ObservableObject {
    
    @Published var isSpeaking: Bool = false
    @Published var audioLevel: Float = 0
    @Published var isMonitoring: Bool = false
    @Published var permissionGranted: Bool = false
    
    private var audioEngine: AVAudioEngine?
    private var silenceTimer: Timer?
    private var smoothedLevel: Float = 0
    
    /// Threshold for detecting speech (0.0 to 1.0)
    var speechThreshold: Float = 0.02
    
    /// How long to wait after silence before stopping (seconds)
    var silenceDelay: TimeInterval = 0.8
    
    /// Smoothing factor for level display (0.0-1.0, higher = more responsive)
    var smoothingFactor: Float = 0.3
    
    init() {
        checkPermission()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Permission
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = false
        case .denied, .restricted:
            permissionGranted = false
        @unknown default:
            permissionGranted = false
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                completion(granted)
            }
        }
    }
    
    // MARK: - Monitoring
    
    func start() {
        guard permissionGranted else {
            requestPermission { [weak self] granted in
                if granted {
                    self?.startMonitoring()
                }
            }
            return
        }
        startMonitoring()
    }
    
    private func startMonitoring() {
        guard !isMonitoring else { return }
        
        // CRITICAL: Dispatch to background queue to avoid crash
        // See: https://levelup.gitconnected.com - installTap must not be on main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupAndStartEngine()
        }
    }
    
    private func setupAndStartEngine() {
        // Create new engine instance
        let engine = AVAudioEngine()
        
        let inputNode = engine.inputNode
        
        // Get the native input format - safer than outputFormat
        let format = inputNode.inputFormat(forBus: 0)
        
        // Check if format is valid (channels > 0, sampleRate > 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            print("[AudioLevelMonitor] Invalid audio format - channels: \(format.channelCount), sampleRate: \(format.sampleRate)")
            DispatchQueue.main.async {
                self.isMonitoring = false
            }
            return
        }
        
        do {
            // Install tap with the input format
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            
            // Prepare and start engine
            engine.prepare()
            try engine.start()
            
            // Store engine reference (must be done before updating state)
            self.audioEngine = engine
            
            DispatchQueue.main.async {
                self.isMonitoring = true
            }
            print("[AudioLevelMonitor] Started monitoring - format: \(format.sampleRate)Hz, \(format.channelCount) channels")
            
        } catch {
            print("[AudioLevelMonitor] Failed to start engine: \(error)")
            // Cleanup on failure
            inputNode.removeTap(onBus: 0)
            DispatchQueue.main.async {
                self.isMonitoring = false
            }
        }
    }
    
    func stop() {
        // Invalidate timer on main thread
        DispatchQueue.main.async {
            self.silenceTimer?.invalidate()
            self.silenceTimer = nil
        }
        
        // Stop engine
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.isSpeaking = false
            self.audioLevel = 0
            self.smoothedLevel = 0
        }
        print("[AudioLevelMonitor] Stopped")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        // Use Accelerate framework for efficient RMS calculation
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
        
        // Normalize to 0-1 range (approximate, adjust based on typical mic levels)
        let normalizedLevel = min(1.0, rms * 8)
        
        // Apply smoothing for display
        let smoothed = smoothingFactor * normalizedLevel + (1 - smoothingFactor) * smoothedLevel
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.smoothedLevel = smoothed
            self.audioLevel = smoothed
            
            if normalizedLevel > self.speechThreshold {
                // Speaking detected
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
                
                if !self.isSpeaking {
                    self.isSpeaking = true
                }
            } else {
                // Silence detected - start timer if not already running
                if self.isSpeaking && self.silenceTimer == nil {
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceDelay, repeats: false) { [weak self] _ in
                        self?.isSpeaking = false
                        self?.silenceTimer = nil
                    }
                }
            }
        }
    }
}
