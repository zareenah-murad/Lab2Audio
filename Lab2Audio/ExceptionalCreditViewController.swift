//
//  ExceptionalCreditViewController.swift
//  Lab2Audio
//
//  Created by Alexandra Geer on 10/11/24.
//  Copyright © 2024 Eric Larson. All rights reserved.

//In our Exceptional Credit project, we focused on real-time Doppler shift detection and visualization by emitting an ultrasonic tone and analyzing how the frequency changes as objects move near the microphone. We developed a system that detects even small shifts in frequency caused by movement using the Doppler effect and visualizes these shifts in a continuously updating graph. As we move our hand, the graph shows red peaks representing the Doppler shifts, while the app labels the movement as "Moving Toward," "Moving Away," or "No Gesture." Unlike Module B, where we focused on gesture detection using FFT, our goal here was to provide real-time feedback on how movement affects the emitted frequency over time, offering a continuous, scientific visualization of Doppler shifts.

import UIKit
import AVFoundation
import Accelerate

class ExceptionalCreditViewController: UIViewController {

    @IBOutlet weak var frequencySlider: UISlider!
    @IBOutlet weak var emittedFreqLabel: UILabel!
    @IBOutlet weak var gestureLabel: UILabel!
    @IBOutlet weak var graphView: UIView!
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    // Graph elements
    var graphLayer: CAShapeLayer!
    var graphPath: UIBezierPath!
    
    // Declare displayLink as a class property
    var displayLink: CADisplayLink?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audio.pause()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        audio.gestureCallback = { [weak self] gestureResult in
            self?.gestureLabel.text = gestureResult
        }
        
        audio.startMicrophoneProcessing(withFps: 30)

        frequencySlider.minimumValue = 17000.0
        frequencySlider.maximumValue = 20000.0
        frequencySlider.value = 17000.0
        self.audio.sineFrequency = frequencySlider.value
        emittedFreqLabel.text = String(format: "Emitted Frequency: %.2f Hz", frequencySlider.value)

        setupGraph()

        audio.startProcessingSinewaveForPlayback(withFreq: frequencySlider.value)
        audio.play()

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        audio.startProcessingSinewaveForPlayback(withFreq: frequencySlider.value)
        audio.play()
    }

    @IBAction func changeFrequency(_ sender: UISlider) {
        self.audio.sineFrequency = sender.value
        emittedFreqLabel.text = String(format: "Emitted Frequency: %.2f Hz", sender.value)
    }

    func setupGraph() {
        graphLayer = CAShapeLayer()
        graphLayer.strokeColor = UIColor.red.cgColor
        graphLayer.lineWidth = 2.0
        graphLayer.fillColor = UIColor.clear.cgColor

        graphPath = UIBezierPath()
        graphLayer.path = graphPath.cgPath

        graphView.layer.addSublayer(graphLayer)

        // Initialize display link and add it to the main run loop
        displayLink = CADisplayLink(target: self, selector: #selector(updateGraphView))
        displayLink?.add(to: .main, forMode: .default)
    }

    func updateGraph() {
        if let peakIdx = audio.fftData.firstIndex(of: audio.fftData.max() ?? 0) {
            let graphWidth = graphView.frame.width
            let graphHeight = graphView.frame.height
            let dopplerShift = audio.fftData[peakIdx]
            let newY = CGFloat(dopplerShift) * 10
            let clampedY = min(max(newY, 0), graphHeight)

            if graphPath.currentPoint.x >= graphWidth {
                graphPath.removeAllPoints()
                graphPath.move(to: CGPoint(x: 0, y: clampedY))
            } else if graphPath.isEmpty {
                graphPath.move(to: CGPoint(x: 0, y: clampedY))
            } else {
                let currentX = graphPath.currentPoint.x + 5
                graphPath.addLine(to: CGPoint(x: currentX, y: clampedY))
            }

            graphLayer.path = graphPath.cgPath
        }
    }

    @objc func updateGraphView() {
        graphLayer.setNeedsDisplay()
    }
}
