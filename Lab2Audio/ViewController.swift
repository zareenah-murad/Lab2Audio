//
//  ViewController.swift
//  Lab2Audio
//


import UIKit
import Metal

class ViewController: UIViewController {
    
    @IBOutlet weak var userView: UIView!
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audio.pause()
        print("audio paused")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup graphs
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display, normalized for FFT
            graph.addGraph(withName: "fft", shouldNormalizeForFFT: true, numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
            
            graph.addGraph(withName: "time", numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            
            graph.addGraph(withName: "equalizer", shouldNormalizeForFFT: true, numPointsInGraph: 20)
            
            graph.makeGrids() // add grids to graph
        }
        
        // start up the audio model, querying the audio file instead of the microphone
        
        audio.startAudioFileProcessing(withFps: 20)  // 20 FPS preferred number of FFT calculations per second
        
        // Play the audio file
        audio.play()
        
        // run the loop for updating the graph periodically
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
    }
    
    // periodically, update the graph with refreshed FFT Data
    func updateGraph(){
        
        if let graph = self.graph{
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            graph.updateGraph(
                data: self.audio.timeData,
                forKey: "time"
            )
            
            graph.updateGraph(
                data: self.audio.equalizerData,
                forKey: "equalizer"
            )
            
            
        }
    }
}
