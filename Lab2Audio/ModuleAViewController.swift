//
//  ModuleAViewController.swift
//  Lab2Audio
//
//  Created by Zareenah Murad on 9/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//
// Group: Alex Geer, Hamna Tameez, Zareenah Murad
//


import UIKit
import Metal

struct AudioConstants {
    // define size of audio buffer
    static let AUDIO_BUFFER_SIZE = 4096
}

// setup audio model
let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)

/*
 PEAK FINDING ALGORITHM:
    * adjust FFT/buffer size for better frequency resolution
    * implement sliding window - create a buffer that stores results of each fft frame across time windows
        and compare them to ensure they're consistent for at least 200 ms
    * modify the peak detection function findTwoLoudestFrequencies() to track peaks over time and
        to discard peaks that are less than 50 Hz apart
    * track frequencies over time and only display if tracked consistently for 200+ ms
 */

class ModuleAViewController: UIViewController {
    
    // frequency labels that will display two loudest frequencies
    @IBOutlet weak var frequencyLabel1: UILabel!
    @IBOutlet weak var frequencyLabel2: UILabel!
    
    
    
    // store last detected loud frequencies, for when no new significant frequencies detected
    var lastLoudFrequencies: (Float, Float) = (0.0, 0.0)
        
    // buffer for peak detection over time (200ms consistency)
    // stores pairs of frequencies from last few frames (4 frames at 20 FPS = 200ms)
    var frequencyBuffer: [(Float, Float)] = []
        
    // max number of frames to keep in the buffer for 200ms duration (20 FPS * 0.2s = 4 frames)
    let maxBufferCount = 4
        
    // track the last detected consistent frequencies over 200ms
    var consistentFrequencies: (Float, Float)? = nil
        
    override func viewDidLoad() {
            super.viewDidLoad()

        // start microphone processing - 20 frames per second (20 FPS for FFT calculations)
        audio.startMicrophoneProcessing(withFps: 20)
        audio.play() // start audio stream and FFT

        // runloop to process the FFT data and update frequencies every 0.05 seconds (20 FPS)
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateFrequencies()
        }
    }
        
    // function called (every 0.05s) to update frequency labels
    func updateFrequencies() {
        let fftData = audio.fftData // get the latest FFT data from the audio model
        let magnitudeThreshold: Float = -40.0 // filter out low-magnitude noise in FFT

        // find two loudest frequencies in the FFT data above the threshold
        if let (freq1, freq2) = findTwoLoudestFrequencies(from: fftData, threshold: magnitudeThreshold) {
            // display frequencies immediately in the UI
            frequencyLabel1.text = String(format: "%.2f Hz", freq1)
            frequencyLabel2.text = String(format: "%.2f Hz", freq2)
                
            // add detected frequencies to buffer to check for consistency over time
            frequencyBuffer.append((freq1, freq2))
            if frequencyBuffer.count > maxBufferCount {
                frequencyBuffer.removeFirst() // keep the buffer limited to the last 200ms
            }
                
            // if frequencies are consistent over time, store as consistent frequencies
            if frequenciesAreConsistent() {
                consistentFrequencies = (freq1, freq2) // frequencies are stable over 200ms
            }
        } else {
            // if no significant frequencies found, lock in the last consistent frequencies
            if let (freq1, freq2) = consistentFrequencies {
                frequencyLabel1.text = String(format: "%.2f Hz", freq1)
                frequencyLabel2.text = String(format: "%.2f Hz", freq2)
            }
        }
    }

    // function to find two loudest frequencies from the FFT data using peak detection
    func findTwoLoudestFrequencies(from fftData: [Float], threshold: Float) -> (Float, Float)? {
        var loudestFrequency1: (index: Int, magnitude: Float) = (0, -Float.greatestFiniteMagnitude) // stores the first loudest frequency
        var loudestFrequency2: (index: Int, magnitude: Float) = (0, -Float.greatestFiniteMagnitude) // stores the second loudest frequency
        
        // loop through FFT data, find two frequencies with the highest magnitudes
        for (index, magnitude) in fftData.enumerated() {
            if magnitude > threshold {
                // update the first loudest frequency
                if magnitude > loudestFrequency1.magnitude {
                    loudestFrequency2 = loudestFrequency1 // move the current loudest to second place
                    loudestFrequency1 = (index, magnitude)
                }
                // update the second loudest frequency, ensure frequencies are at least 50Hz apart
                else if magnitude > loudestFrequency2.magnitude && abs(frequencyFromIndex(index) - frequencyFromIndex(loudestFrequency1.index)) > 50 {
                    loudestFrequency2 = (index, magnitude)
                }
            }
        }

        // if valid peaks found, return their frequencies, otherwise nil
        if loudestFrequency1.magnitude == -Float.greatestFiniteMagnitude || loudestFrequency2.magnitude == -Float.greatestFiniteMagnitude {
            return nil
        }

        return (frequencyFromIndex(loudestFrequency1.index), frequencyFromIndex(loudestFrequency2.index)) // return the two detected frequencies
    }

    // check if frequencies stored in the buffer are consistent over time (200ms)
    func frequenciesAreConsistent() -> Bool {
        guard frequencyBuffer.count == maxBufferCount else { return false } // ensure buffer is full (200ms worth of data)
        let first = frequencyBuffer.first! // take the first pair of frequencies in buffer
        return frequencyBuffer.allSatisfy { $0 == first } // check if all pairs in buffer are the same
    }

    // helper function - convert FFT bin index into a frequency value in Hz
    func frequencyFromIndex(_ index: Int) -> Float {
        let nyquist = Float(audio.samplingRate) / 2.0 // Nyquist frequency = half the sampling rate
        let binWidth = nyquist / Float(AudioConstants.AUDIO_BUFFER_SIZE / 2) // Calculate the width of each frequency bin
        return Float(index) * binWidth // convert bin index into a frequency value
    }
}
