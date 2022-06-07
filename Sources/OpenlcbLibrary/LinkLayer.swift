//
//  LinkLayer.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Handles link-layer formatting and unformatting for a particular kind of communications link.
///
/// Nodes are handled in one of two ways:
///    - "Own Node" - this is a node resident within the program
///    - "Remote Node" - this is a node outside the program
///
///  This is a class, not a struct, because an instance corresponds to an external object (the actual link implementation), so
///  there's no semantic meaning to making multiple copies of a single object.
///
public class LinkLayer {
    enum State {
        case Initial // a special case of .Inhibited where initialization hasn't started
        case Inhibited
        case Permitted
    }

    func sendMessage(_ msg : Message) {}
    
    func registerMessageReceivedListener(_ listener : @escaping ( (_ : Message) -> () )) {
        listeners.append(listener)
    }
    var listeners : [( (_ : Message) -> () )] = []
    
    func fireListeners(_ frame : Message) {
        for listener in listeners {
            listener(frame)
        }
    }
    
    // invoked when the link layer comes up and down
    func linkStateChange(state : State) {
        // let cf = CanFrame(control : CanLink.ControlFrame.LinkUp.rawValue, alias : 0)
        // fireListeners(cf)
    }

}
