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
    public init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer?

    public func process( _ message : Message, _ node : Node ) {
        switch message.mti {
        case MTI.Datagram :
            break // TODO: handle datagram-related MTIs
        case MTI.DatagramRejected :
            break
        case MTI.DatagramReceivedOK :
            break
        default:
            // no need to do anything
            break
        }
    }
}
