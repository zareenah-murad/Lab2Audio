//
//  AudioModel.swift
//  Lab2Audio
//
// Group: Alex Geer, Hamna Tameez, Zareenah Murad

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    var equalizerData:[Float]
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    // Audio file reader
    private lazy var fileReader: AudioFileReader? = {
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3") {
            var tmpFileReader: AudioFileReader? = AudioFileReader.init(audioFileURL: url, samplingRate: Float(audioManager!.samplingRate), numChannels: audioManager!.numOutputChannels)
            tmpFileReader!.currentTime = 0.0
            print("Audio file successfully loaded for \(url)")
            return tmpFileReader
        } else {
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        equalizerData = Array.init(repeating: 0.0, count: 20)
    }
    
    //    // Public function for starting processing of microphone data
    //    func startMicrophoneProcessing(withFps: Double) {
    //        // setup the microphone to copy to circular buffer
    //        if let manager = self.audioManager {
    //            manager.inputBlock = self.handleMicrophone
    //
    //            // repeat this fps times per second using the timer class
    //            Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
    //                self.runEveryInterval()
    //            }
    //        }
    //    }
    
    // Function to start processing the audio file (instead of microphone input)
    
    func startAudioFileProcessing(withFps: Double) {
        guard let manager = self.audioManager else { return }
        
        // Set the output block to process audio file instead of microphone input
        manager.outputBlock = self.handleSpeakerQueryWithAudioFile
        
        // Set a timer to run every frame and update the equalizer data
        Timer.scheduledTimer(withTimeInterval: 1.0 / withFps, repeats: true) { _ in
            self.runEveryInterval()
        }
        
        // Play the audio file using the audio manager
        manager.play()
    }
    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    func pause(){
        if let manager = self.audioManager{
            manager.pause()
            print("Audio Paused")
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    // NONE for this model
    
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            //   equalizerData: max of 20 windows of fftData
            
            // Windowing for EQ data
            let fftDataSize = BUFFER_SIZE / 2
            let newWindow = fftDataSize / 20
            
            var j = 0
            for i in stride(from: 0, to: fftDataSize - newWindow, by: newWindow) {
                let fftSlice = Array(fftData[i..<i+newWindow]) // Slice of fftData
                var maxValue: Float = 0.0
                vDSP_maxv(fftSlice, 1, &maxValue, vDSP_Length(newWindow)) // Max from slice
                equalizerData[j] = maxValue
                j += 1
            }
        }
        
        
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    //    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
    //        // copy samples from the microphone into circular buffer
    //        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    //    }
    
    // MARK: Audiocard Callbacks
    
    private func handleSpeakerQueryWithAudioFile(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let file = self.fileReader {
            // reads audio data from the file
            file.retrieveFreshAudio(data, numFrames: numFrames, numChannels: numChannels)
            // loads it into the input buffer
            self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
        }
    }
    
}

