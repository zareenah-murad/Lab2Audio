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
    @IBOutlet weak var gestureLabel: UILabel!

    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 8  // Increase this if necessary for better resolution
    }

    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)

    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop gesture detection and audio playback when the view disappears
        audio.pause()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the callback to update the gesture label when gesture detection occurs
        audio.gestureCallback = { [weak self] gestureResult in
            self?.gestureLabel.text = gestureResult
        }

        // Read from microphone in real time
        audio.startMicrophoneProcessing(withFps: 30)

        frequencySlider.minimumValue = 17000.0
        frequencySlider.maximumValue = 20000.0
        frequencySlider.value = 17000.0
        self.audio.sineFrequency = frequencySlider.value
        freqLabel.text = String(format: "Frequency: %.2f Hz", frequencySlider.value)

        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            graph.addGraph(withName: "zoomedFFT", shouldNormalizeForFFT: true, numPointsInGraph: 400)
            graph.makeGrids()
        }

        audio.startProcessingSinewaveForPlayback(withFreq: frequencySlider.value)
        audio.play()

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Resume gesture detection and audio playback when the view appears again
        audio.play()
    }

    @IBAction func changeFrequency(_ sender: UISlider) {
        self.audio.sineFrequency = sender.value
        freqLabel.text = String(format: "Frequency: %.2f Hz", sender.value)
    }

    // periodically, update the graph with refreshed FFT Data
    func updateGraph() {
        if let graph = self.graph {
            let startFreq: Float = 17000.0
            let endFreq: Float = 20000.0

            let startIdx = max(0, Int(startFreq * Float(AudioConstants.AUDIO_BUFFER_SIZE) / Float(audio.samplingRate)))
            let endIdx = min(audio.fftData.count - 1, Int(endFreq * Float(AudioConstants.AUDIO_BUFFER_SIZE) / Float(audio.samplingRate)))

            if startIdx < audio.fftData.count && endIdx < audio.fftData.count {
                let subArray = Array(audio.fftData[startIdx...endIdx])
                graph.updateGraph(data: subArray, forKey: "zoomedFFT")
            }
        }
    }
}


