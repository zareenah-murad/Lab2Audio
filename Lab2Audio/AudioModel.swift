//
//  AudioModel.swift
//  Lab2Audio
//
// Group: Alex Geer, Hamna Tameez, Zareenah Murad

import Foundation
import Accelerate
import AVFoundation

class AudioModel {

    // MARK: Properties
    private var BUFFER_SIZE:Int
    // These properties are for interfacing with the API
    // The user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    var dBData:[Float] // Add dBData as a property
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
  
    // MARK: Public Methods
    init(buffer_size: Int) {
        BUFFER_SIZE = buffer_size
        // Anything not lazily instantiated should be allocated here
        timeData = Array(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array(repeating: 0.0, count: BUFFER_SIZE/2)
        dBData = Array(repeating: 0.0, count: BUFFER_SIZE/2) // Initialize dBData
    }

    // Public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps: Double) {
            // Repeat this fps times per second using the timer class
            // Every time this is called, we update the arrays "timeData" and "fftData"
        timeData = Array(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array(repeating: 0.0, count: BUFFER_SIZE / 2)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .defaultToSpeaker)
            try audioSession.setActive(true)
            print("AVAudioSession successfully configured.")
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }

        if let manager = self.audioManager {
            manager.inputBlock = self.handleMicrophone
          
            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
        }
    }

    func startProcessingSinewaveForPlayback(withFreq: Float = 330.0) {
        sineFrequency = withFreq
        if let manager = self.audioManager {
            // Swift sine wave loop creation
            manager.outputBlock = self.handleSpeakerQueryWithSinusoid
        }
    }

    func getPeakIndex() -> Int? {
        var maxIndex: vDSP_Length = 0
        var maxValue: Float = 0.0
        vDSP_maxvi(dBData, 1, &maxValue, &maxIndex, vDSP_Length(dBData.count))
        return Int(maxIndex)
    }

    func getZoomedDBData(zoomRange: Int) -> [Float]? {
        guard let maxIndex = getPeakIndex() else { return nil }

        let start = max(0, maxIndex - zoomRange)
        let end = min(dBData.count, maxIndex + zoomRange)

        // Return the zoomed-in dB data
        return Array(dBData[start..<end])
    }
  
    // You must call this when you want the audio to start being handled by our model
    func play() {
        if let manager = self.audioManager {
            manager.play()
        }
    }

    func pause() {
        if let manager = self.audioManager {
            manager.pause()
            print("Audio Paused")
        }
    }

    //==========================================
    // MARK: Private Properties
    private lazy var audioManager: Novocaine? = {
        return Novocaine.audioManager()
    }()

    private lazy var fftHelper: FFTHelper? = {
        return FFTHelper(fftSize: Int32(BUFFER_SIZE))
    }()

    private lazy var inputBuffer: CircularBuffer? = {
        return CircularBuffer(numChannels: Int64(self.audioManager!.numInputChannels),
                              andBufferSize: Int64(BUFFER_SIZE))
    }()

    // Define properties for tracking previous peak frequency
    private var previousPeakFrequency: Float? = nil
    private var previousMaxValue: Float = 0.0 // Add this for magnitude comparison
    //private var smoothedFrequency: Float = 0.0
    //private let smoothingFactor: Float = 0.2 // Adjust as needed
    private let gestureThreshold: Float = 10.0 // Adjust threshold for detecting gestures

    // Gesture detection timing
    private var lastGestureTime: Date = Date()
    private let gestureBufferTime: TimeInterval = 0.5 // Half a second buffer between detections

    // Smoothing function
//    private func smoothFrequency(_ newFrequency: Float) -> Float {
//        smoothedFrequency = smoothedFrequency * (1.0 - smoothingFactor) + newFrequency * smoothingFactor
//        return smoothedFrequency
//    }

    private func canDetectGesture() -> Bool {
        return abs(lastGestureTime.timeIntervalSinceNow) > gestureBufferTime
    }

    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval() {
        if inputBuffer != nil {
            // Copy time data (audio samples) to Swift array
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))

            // Perform FFT
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)

            // Compute magnitudes in dB
            var zeroDB: Float = 1e-10 // Small value to avoid log(0)
            var magData = [Float](repeating: 0.0, count: BUFFER_SIZE / 2)

            // Square the magnitudes (vDSP_vsq)
            vDSP_vsq(fftData, 1, &magData, 1, vDSP_Length(BUFFER_SIZE / 2))

            // Normalize the magnitudes by dividing by the buffer size
            var normalizationFactor: Float = 1.0 / Float(BUFFER_SIZE)
            vDSP_vsmul(magData, 1, &normalizationFactor, &magData, 1, vDSP_Length(BUFFER_SIZE / 2))

            // Add small value to avoid log(0)
            vDSP_vsadd(magData, 1, &zeroDB, &magData, 1, vDSP_Length(BUFFER_SIZE / 2))

            // Convert to dB and store in self.dBData
            var scale: Float = 10.0
            vDSP_vdbcon(magData, 1, &scale, &dBData, 1, vDSP_Length(BUFFER_SIZE / 2), 1)

            // Find the peak frequency in dB data
            var maxIndex: vDSP_Length = 0
            var maxValue: Float = 0.0
            vDSP_maxvi(dBData, 1, &maxValue, &maxIndex, vDSP_Length(dBData.count))

            let peakFrequency = Float(maxIndex) * (Float(samplingRate) / Float(BUFFER_SIZE))
            //let smoothedPeakFrequency = smoothFrequency(peakFrequency)

            // Doppler Shift Detection: Detect gestures based on frequency and magnitude change
            if let previousFrequency = previousPeakFrequency {
                let frequencyShift = peakFrequency - previousFrequency
                let magnitudeThreshold: Float = 2.0

                // Check both frequency and magnitude
                if abs(frequencyShift) > gestureThreshold && abs(maxValue - previousMaxValue) > magnitudeThreshold {
                    if canDetectGesture() {
                        if frequencyShift > 0 {
                            print("Gesture Toward Detected")
                        } else {
                            print("Gesture Away Detected")
                        }
                        lastGestureTime = Date() // Update last gesture time
                    }
                } else {
                    print("No Gesture Detected")
                }
            }

            // Update previous values for the next iteration
            previousPeakFrequency = peakFrequency
            previousMaxValue = maxValue
        }
    }

    //==========================================
    // MARK: Audiocard Callbacks
    private func handleMicrophone(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        // Copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }

    var sineFrequency: Float = 0.0 { // Frequency in Hz (changeable by user)
        didSet {
            if let manager = self.audioManager {
                // Update phase increment when frequency changes
                phaseIncrement = Float(2 * Double.pi * Double(sineFrequency) / manager.samplingRate)
            }
        }
    }

    // SWIFT SINE WAVE
    // Everything below here is for the swift implementation
    private var phase: Float = 0.0
    private var phaseIncrement: Float = 0.0
    private var sineWaveRepeatMax: Float = Float(2 * Double.pi)

    private func handleSpeakerQueryWithSinusoid(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let arrayData = data {
            var i = 0
            let chan = Int(numChannels)
            let frame = Int(numFrames)
            let amplitude: Float = 0.5 // Adjust amplitude as needed

            if chan == 1 {
                while i < frame {
                    arrayData[i] = amplitude * sin(phase)
                    phase += phaseIncrement
                    if phase >= sineWaveRepeatMax { phase -= sineWaveRepeatMax }
                    i += 1
                }
            } else if chan == 2 {
                let len = frame * chan
                while i < len {
                    arrayData[i] = amplitude * sin(phase)
                    arrayData[i + 1] = arrayData[i] // Duplicate for stereo
                    phase += phaseIncrement
                    if phase >= sineWaveRepeatMax { phase -= sineWaveRepeatMax }
                    i += 2
                }
            }
        }
    }
}
