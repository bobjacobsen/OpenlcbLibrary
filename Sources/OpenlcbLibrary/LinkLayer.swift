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

    init(_ localNodeID : NodeID ) {
        self.localNodeID = localNodeID
    }
    public let localNodeID : NodeID // valid default node ID

    public func sendMessage(_ msg : Message) {}
    
    func registerMessageReceivedListener(_ listener : @escaping ( (_ : Message) -> () )) {
        listeners.append(listener)
    }
    var listeners : [( (_ : Message) -> () )] = []
    
    func fireListeners(_ msg : Message) {
        for listener in listeners {
            listener(msg)
        }
    }
    
    // invoked when the link layer comes up and down
    func linkStateChange(state : State) {
        var msg : Message
        if state == State.Permitted {
            msg = Message(mti: MTI.Link_Level_Up, source: NodeID(0) )
        } else {
            msg = Message(mti: MTI.Link_Level_Down, source: NodeID(0) )
        }
        fireListeners(msg)
    }

}
