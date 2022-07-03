//
//  DatagramProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Handle incoming messages for a datagram service that can send and receive datagrams.
///
/// Works with ``DatagramService`` which holds context; this struct must remain immutable
/// 
struct DatagramProcessor : Processor {
    public init ( _ linkLayer: LinkLayer? = nil) {
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer?

    public func process( _ message : Message, _ node : Node ) {
        switch message.mti {
        case MTI.Datagram :
            handleDatagram(message)
        case MTI.Datagram_Rejected :
            handleDatagramRejected(message)
        case MTI.Datagram_Received_OK :
            handleDatagramReceivedOK(message)
        default:
            // no need to do anything
            break
        }
    }
    
    func handleDatagram(_ message : Message) {
            // TODO: handle Datagram
    }

    func handleDatagramReceivedOK(_ message : Message) {
            // TODO: handle DatagramReceivedOK
    }
    
    func handleDatagramRejected(_ message : Message) {
            // TODO: handle DatagramRejected
    }
    
}

