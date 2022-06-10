//
//  CanPhysicalLayerMock.swift
//  
//
//  Created by Bob Jacobsen on 6/9/22.
//

import Foundation
@testable import OpenlcbLibrary

/// Mock CanPhysicalLayer to record frames requested to be sent
class CanPhysicalLayerMock : CanPhysicalLayer {
    var receivedFrames : [CanFrame] = []
    override func sendCanFrame(_ frame : CanFrame) { receivedFrames.append(frame) }
}

