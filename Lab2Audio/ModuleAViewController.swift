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
    static let AUDIO_BUFFER_SIZE = 1024 * 4
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
    
    // stores last detected loud frequencies
    // allows UI to retain the last values when no significant frequencies are detected
    var lastLoudFrequencies: (Float, Float) = (0.0, 0.0)

        override func viewDidLoad() {
            super.viewDidLoad()

            // start microphone processing
            audio.startMicrophoneProcessing(withFps: 20) // calculating fft 20 frames per second
            // start audio processing
            audio.play()
                    
            // runloop to process the FFT periodically
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.updateFrequencies() // update the frequency labels
            }
        }
        
        // Periodically updates the two loudest frequencies based on FFT data
        func updateFrequencies() {
            // get fft data from audio model
            let fftData = audio.fftData
            
            // threshold to filter out low-magnitude frequencies (noise)
            let magnitudeThreshold: Float = -40.0 // frequencies with magnitudes above -40 will be considered

            // find the two loudest frequencies above the threshold
            if let (freq1, freq2) = findTwoLoudestFrequencies(from: fftData, threshold: magnitudeThreshold) {
                // if found, update the labels
                frequencyLabel1.text = String(format: "%.2f Hz", freq1)
                frequencyLabel2.text = String(format: "%.2f Hz", freq2)
                
                // save detected frequencies for later if no significant frequencies are detected
                lastLoudFrequencies = (freq1, freq2)
            }
            // no significant frequencies found, lock in the last loud frequencies
            else {
                frequencyLabel1.text = String(format: "%.2f Hz", lastLoudFrequencies.0)
                frequencyLabel2.text = String(format: "%.2f Hz", lastLoudFrequencies.1)
            }
        }
        
        // finds the two loudest frequencies from the FFT data
        func findTwoLoudestFrequencies(from fftData: [Float], threshold: Float) -> (Float, Float)? {
            // loudest frequency detected
            var loudestFrequency1: (index: Int, magnitude: Float) = (0, -Float.greatestFiniteMagnitude)
            // second loudest frequency detected
            var loudestFrequency2: (index: Int, magnitude: Float) = (0, -Float.greatestFiniteMagnitude)
            
            // loop through FFT data to find the 2 frequencies with the highest magnitudes
            for (index, magnitude) in fftData.enumerated() {
                // only consider frequencies above the threshold
                if magnitude > threshold {
                    if magnitude > loudestFrequency1.magnitude {
                        loudestFrequency2 = loudestFrequency1 // move current loudest to second place
                        loudestFrequency1 = (index, magnitude) // update loudest frequency
                    } else if magnitude > loudestFrequency2.magnitude {
                        loudestFrequency2 = (index, magnitude) // update second loudest frequency
                    }
                }
            }

            // convert the FFT indices to actual frequencies
            let freq1 = frequencyFromIndex(loudestFrequency1.index)
            let freq2 = frequencyFromIndex(loudestFrequency2.index)

            // check if the frequencies are very close (less than 10 Hz apart), may indicate they are harmonics
            if abs(freq1 - freq2) < 10 { // avoid harmonics by ignoring frequencies that are too close
                return (freq1, lastLoudFrequencies.1) // return loudest frequency and retain the last second loud frequency
            }

            // if no significant frequencies are found, return nil
            if loudestFrequency1.magnitude == -Float.greatestFiniteMagnitude {
                return nil
            }

            // return the two loudest frequencies
            return (freq1, freq2)
        }
        
        // helper function to convert an FFT bin index into a frequency value in Hz
        func frequencyFromIndex(_ index: Int) -> Float {
            // nyquist frequency is half the sampling rate
            let nyquist = Float(audio.samplingRate) / 2.0
            
            // width of each frequency bin is Nyquist frequency divided by the # of FFT bins
            let binWidth = nyquist / Float(AudioConstants.AUDIO_BUFFER_SIZE / 2)
            
            // actual frequency is index multiplied by bin width
            return Float(index) * binWidth
        }
    }