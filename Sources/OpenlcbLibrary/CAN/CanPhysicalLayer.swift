//
//  CanPhysicalLayer.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Generalize a CAN physica layer, real or simulated.
/// This is a class because it represents a single physical connection to a layout and is subclassed.
/// 
public class CanPhysicalLayer : PhysicalLayer {
    public init() {
    }

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
    public func physicalLayerUp() {
        // notify link layer
        let cf = CanFrame(control : CanLink.ControlFrame.LinkUp.rawValue, alias : 0)
        fireListeners(cf)
    }
    public func physicalLayerDown() {
        // notify link layer
        let cf = CanFrame(control : CanLink.ControlFrame.LinkDown.rawValue, alias : 0)
        fireListeners(cf)
    }
    
}
