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
    private let gestureThreshold: Float = 21.0  // Threshold to detect significant movement
    private let noGestureThresholdTime: TimeInterval = 1.0  // Time after which "No Gesture" is displayed
    private var lastGestureTime: Date = Date()  // Tracks the last time a gesture was detected
    private var lastGesture: String = "No Gesture"  // Track the last gesture (toward or away)
    private var smoothedFrequency: Float = 0.0
    private let smoothingFactor: Float = 0.1
    private let gestureBufferTime: TimeInterval = 0.5

    // Closure callback to update the gesture label in the UI
    var gestureCallback: ((String) -> Void)?

    // Public property to store the gesture result
    var gestureResult: String = "No Gesture" {
        didSet {
            gestureCallback?(gestureResult)
        }
    }

    // MARK: Public Methods
    init(buffer_size: Int) {
        BUFFER_SIZE = buffer_size
        timeData = Array(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array(repeating: 0.0, count: BUFFER_SIZE / 2)
    }

    func startMicrophoneProcessing(withFps: Double) {
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

    // MARK: Doppler Shift Detection
    private func runEveryInterval() {
        if inputBuffer != nil {
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)

            let peakFrequency = sineFrequency
            var maxIndex = Int(peakFrequency * Float(BUFFER_SIZE) / Float(samplingRate))

            let windowSize = 10
            let leftStart = max(0, maxIndex - windowSize)
            let leftEnd = maxIndex
            let rightStart = maxIndex
            let rightEnd = min(fftData.count - 1, maxIndex + windowSize)

            let leftValues = Array(fftData[leftStart..<leftEnd])
            let rightValues = Array(fftData[rightStart..<rightEnd])

            let leftAverage = leftValues.reduce(0, +) / Float(leftValues.count)
            let rightAverage = rightValues.reduce(0, +) / Float(rightValues.count)

            let validLeft = leftValues.count > 0
            let validRight = rightValues.count > 0

            if validLeft && validRight {
                if leftAverage < rightAverage && abs(leftAverage - rightAverage) > gestureThreshold {
                    gestureResult = "Gesture Toward Detected"
                    lastGesture = "Gesture Toward"
                    lastGestureTime = Date()
                } else if rightAverage < leftAverage && abs(rightAverage - leftAverage) > gestureThreshold {
                    gestureResult = "Gesture Away Detected"
                    lastGesture = "Gesture Away"
                    lastGestureTime = Date()
                } else {
                    if abs(lastGestureTime.timeIntervalSinceNow) > noGestureThresholdTime {
                        gestureResult = "No Gesture"
                        lastGesture = "No Gesture"
                    }
                }
            } else {
                if abs(lastGestureTime.timeIntervalSinceNow) > noGestureThresholdTime {
                    gestureResult = "No Gesture"
                    lastGesture = "No Gesture"
                }
            }

            print("Current Gesture: \(gestureResult)")
        }
    }

    private func handleMicrophone(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }

    var sineFrequency: Float = 0.0 {
        didSet {
            if let manager = self.audioManager {
                phaseIncrement = Float(2 * Double.pi * Double(sineFrequency) / manager.samplingRate)
            }
        }
    }

    private var phase: Float = 0.0
    private var phaseIncrement: Float = 0.0
    private var sineWaveRepeatMax: Float = Float(2 * Double.pi)

    private func handleSpeakerQueryWithSinusoid(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let arrayData = data {
            var i = 0
            let chan = Int(numChannels)
            let frame = Int(numFrames)
            let amplitude: Float = 0.5

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
                    arrayData[i + 1] = arrayData[i]
                    phase += phaseIncrement
                    if phase >= sineWaveRepeatMax { phase -= sineWaveRepeatMax }
                    i += 2
                }
            }
        }
    }
}

