//
//  DatagramService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Provide a service interface for reading and writing Datagrams
///
/// Works with ``DatagramProcessor``
/// 
public class DatagramService {
    // Memo carries request and reply
    struct DatagramMemo {
        let node : Node
        let okReply : ( (_ : Message) -> () )?
        let rejectedReply : ( (_ : Message) -> () )?

        let data : [UInt8] = []
    }
    
    func sendDatagram(_ memo : DatagramMemo) {
        // TODO: Create a datagram message and forward
    }
    
    func registerDatagramReceivedListener(_ listener : @escaping ( (_ : Datagram) -> () )) {
        listeners.append(listener)
    }
    var listeners : [( (_ : Datagram) -> () )] = []
    
    func fireListeners(_ dg : Datagram) {
        for listener in listeners {
            listener(dg)
        }
    }

}
