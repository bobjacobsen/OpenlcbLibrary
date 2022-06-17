//
//  CanPhysicalLayerSimulation.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Simulated CanPhysicalLayer to record frames requested to be sent
public class CanPhysicalLayerSimulation : CanPhysicalLayer {
    var receivedFrames : [CanFrame] = []
    override func sendCanFrame(_ frame : CanFrame) { receivedFrames.append(frame) }
}
