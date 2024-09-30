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
    var fftData: [Float]
    
    lazy var samplingRate: Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
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
    
    // You must call this when you want the audio to start being handled by our model
    func play() {
        if let manager = self.audioManager {
            manager.play()
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
        return CircularBuffer(numChannels: Int64(self.audioManager!.numInputChannels), andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval() {
        if inputBuffer != nil {
            // Copy time data (audio samples) to Swift array
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))

            // Perform FFT
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)

            // Now we have updated timeData (audio samples) and fftData (FFT of the samples)
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    private func handleMicrophone(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
}
