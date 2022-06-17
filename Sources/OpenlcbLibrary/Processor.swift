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

    // TODO; do we need a call to say "is this message interesting?",
    // to shortcut N nodes doing nothing? Or move iteration to here?
}
