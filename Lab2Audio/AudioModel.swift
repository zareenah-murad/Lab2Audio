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
    private var BUFFER_SIZE: Int
    var timeData: [Float]
    var fftData: [Float] // fftData is in dB
    lazy var samplingRate: Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    private var previousPeakFrequency: Float? = nil
    private var previousMaxValue: Float = 0.0
    private var smoothedFrequency: Float = 0.0
    private let smoothingFactor: Float = 0.1
    private let gestureThreshold: Float = 1.0
    private var lastGestureTime: Date = Date()
    private let gestureBufferTime: TimeInterval = 0.5

    // Public property to store the gesture result
    var gestureResult: String = "No Gesture"

    // MARK: Public Methods
    init(buffer_size: Int) {
        BUFFER_SIZE = buffer_size
        timeData = Array(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array(repeating: 0.0, count: BUFFER_SIZE / 2)
    }

    func startMicrophoneProcessing(withFps: Double) {
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
            manager.outputBlock = self.handleSpeakerQueryWithSinusoid
        }
    }

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

    // Smoothing function
    private func smoothFrequency(_ newFrequency: Float) -> Float {
        smoothedFrequency = smoothedFrequency * (1.0 - smoothingFactor) + newFrequency * smoothingFactor
        return smoothedFrequency
    }

    private func canDetectGesture() -> Bool {
        return abs(lastGestureTime.timeIntervalSinceNow) > gestureBufferTime
    }

    //==========================================
    // MARK: Model Callback Methods
    
    // MARK: Doppler Shift Detection
    private func runEveryInterval() {
        if inputBuffer != nil {
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))

            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)

            var maxIndex: vDSP_Length = 0
            var maxValue: Float = 0.0
            vDSP_maxvi(fftData, 1, &maxValue, &maxIndex, vDSP_Length(fftData.count))

            let peakFrequency = Float(maxIndex) * (Float(samplingRate) / Float(BUFFER_SIZE))
            let smoothedPeakFrequency = smoothFrequency(peakFrequency)

            if let previousFrequency = previousPeakFrequency {
                let frequencyShift = smoothedPeakFrequency - previousFrequency
                let magnitudeThreshold: Float = 0.5

                if abs(frequencyShift) > gestureThreshold && abs(maxValue - previousMaxValue) > magnitudeThreshold {
                    if canDetectGesture() {
                        if frequencyShift > 0 {
                            print("Gesture Toward Detected (Doppler Shift: \(frequencyShift) Hz)")
                        } else {
                            print("Gesture Away Detected (Doppler Shift: \(frequencyShift) Hz)")
                        }
                        lastGestureTime = Date()
                    }
                } else {
                    print("No Gesture Detected")
                }
            }

            previousPeakFrequency = smoothedPeakFrequency
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
