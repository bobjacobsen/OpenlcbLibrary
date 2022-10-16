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
    
    /// Invoked from OpenlcbNetwork when the physical link implementation has initially come up
    public func physicalLayerUp() {
        // notify link layer
        let cf = CanFrame(control : CanLink.ControlFrame.LinkUp.rawValue, alias : 0)
        fireListeners(cf)
    }
    
    /// Invoked from OpenlcbNetwork when the physical link implementation has come up 2nd or later times
    public func physicalRestart() {
        // notify link layer
        let cf = CanFrame(control : CanLink.ControlFrame.LinkRestarted.rawValue, alias : 0)
        fireListeners(cf)
    }
    
    /// Invoked from OpenlcbNetwork when the physical link implementation has gone down
    // TODO: Is this invoked? Used?
    public func physicalLayerDown() {
        // notify link layer
        let cf = CanFrame(control : CanLink.ControlFrame.LinkDown.rawValue, alias : 0)
        fireListeners(cf)
    }
    
}
