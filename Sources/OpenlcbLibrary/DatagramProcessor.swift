//
//  DatagramProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Handle incoming messages for a datagram service that can send and receive datagrams.
///
/// Works with ``DatagramService``
/// 
struct DatagramProcessor : Processor {
    public func process( _ message : Message, _ node : Node) {
        switch message.mti {
        default:
            // no need to do anything
            break
        }
    }
}
