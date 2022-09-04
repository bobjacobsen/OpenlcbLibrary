//
//  Processor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Process an incoming message, adjusting state and replying as needed.
///
///  Acts on a specific node
///

public protocol Processor {
    /// accept a Message, adjust state as needed, possibly reply
    func process( _ message : Message, _ node : Node )

    // TODO: do we need a call to say "is this message interesting?", to shortcut N node calls doing nothing?
}

extension Processor {
    // check whether a message came from a specific node
    internal func checkSourceID(_ message : Message, _ node : Node) -> Bool {
        return message.source == node.id
    }
    
    // check whether a message is addressed to a specific node
    // Global messages return false: Not specifically addressed
    internal func checkDestID(_ message : Message, _ node : Node) -> Bool {
        return message.destination == node.id
    }
}
