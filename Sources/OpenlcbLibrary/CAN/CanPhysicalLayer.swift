//
//  CanPhysicalLayer.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// This is a class because it represents a single physical connection to a layout. Subclasses will handle CAN, TCP/IP and test implementations.
/// 
public class CanPhysicalLayer : PhysicalLayer {
    func sendCanFrame(_ frame : CanFrame) {}
    
    func registerFrameReceivedListener(_ listener : @escaping ( (_ : CanFrame) -> () )) {
        listeners.append(listener)
    }
    var listeners : [( (_ : CanFrame) -> () )] = []
    
    func fireListeners(_ frame : CanFrame) {
        for listener in listeners {
            listener(frame)
        }
    }
    
    // invoked when the physical implementation has actually come up
    func physicalLayerUp() {
        // notify link level
        let cf = CanFrame(control : CanLink.ControlFrame.LinkUp.rawValue, alias : 0)
        fireListeners(cf)
    }
    func physicalLayerDown() {
        // notify link level
        let cf = CanFrame(control : CanLink.ControlFrame.LinkDown.rawValue, alias : 0)
        fireListeners(cf)
    }
    
}
