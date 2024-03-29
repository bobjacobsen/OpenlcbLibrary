//
//  Processor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Process an incoming message, adjusting state and replying as needed.
///
///  Acts on a specific node
public protocol Processor {
    /// accept a Message, adjust state as needed, possibly reply
    ///  Returns: True is the contains of the node changed in a way that should be published, i.e. a PIP, SNIP or event model change
    func process( _ message : Message, _ node : Node ) -> Bool
}

extension Processor {
    // check whether a message came from a specific nodeID
    internal func checkSourceID(_ message : Message, _ nodeID : NodeID) -> Bool {
        return message.source == nodeID
    }
    
    // check whether a message came from a specific node
    internal func checkSourceID(_ message : Message, _ node : Node) -> Bool {
        return checkSourceID(message, node.id)
    }

    // check whether a message is addressed to a specific nodeID
    // Global messages return false: Not specifically addressed
    internal func checkDestID(_ message : Message, _ nodeID : NodeID) -> Bool {
        return message.destination == nodeID
    }
    
    // check whether a message is addressed to a specific node
    // Global messages return false: Not specifically addressed
    internal func checkDestID(_ message : Message, _ node : Node) -> Bool {
        return checkDestID(message, node.id)
    }
}
