//
//  ModuleBViewController.swift
//  Lab2Audio
//
//  Created by Zareenah Murad on 9/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//
// Group: Alex Geer, Hamna Tameez, Zareenah Murad
//

import UIKit
import Metal

class ModuleBViewController: UIViewController {

    @IBOutlet weak var frequencySlider: UISlider!
    @IBOutlet weak var userView: UIView!
    @IBOutlet weak var freqLabel: UILabel!

    @IBAction func changeFrequency(_ sender: UISlider) {
        self.audio.sineFrequency = sender.value
        freqLabel.text = String(format: "Frequency: %.2f Hz", sender.value)
    }

    // MARK: 1. Setup some constants we will use
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }

    // MARK: 2. The instantiation of the Audio Model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)

    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        print("entered Module B")

        // Read from microphone in real time
        audio.startMicrophoneProcessing(withFps: 30)

        // Configure slider to have a range from 17,000 Hz to 20,000 Hz
        frequencySlider.minimumValue = 17000.0
        frequencySlider.maximumValue = 20000.0

        // Set default frequency to 17,000 Hz
        frequencySlider.value = 17000.0

        // Update frequency and label
        self.audio.sineFrequency = frequencySlider.value
        freqLabel.text = String(format: "Frequency: %.2f Hz", frequencySlider.value)

        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)

            // Add graph for zoomed-in FFT data
            graph.addGraph(withName: "zoomedFFT", shouldNormalizeForFFT: true, numPointsInGraph: 20)

            graph.makeGrids() // Add grids to graph
        }

        audio.startProcessingSinewaveForPlayback(withFreq: frequencySlider.value)
        audio.play()

        // Run the loop for updating the graph periodically
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
    }

    // Periodically, update the graph with refreshed FFT Data
    func updateGraph() {
        if let graph = self.graph {
            // Get zoomed-in dB data from the AudioModel
            if let zoomedData = self.audio.getZoomedDBData(zoomRange: 10) {
                // Update the zoomed-in FFT graph with the zoomed dB data
                graph.updateGraph(data: zoomedData, forKey: "zoomedFFT")
            }
        }
    }
}
