//
//  DatagramService.swift
//  
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Provide a service interface for reading and writing Datagrams
///
/// Works with and holds context for ``DatagramProcessor``
/// 
public class DatagramService {
    // Memo carries write request and two reply callbacks
    struct DatagramMemo {
        let srcNode : Node
        let destNode : Node
        let okReply : ( (_ : Message) -> () )?
        let rejectedReply : ( (_ : Message) -> () )?

        let data : [UInt8] = []
    }
    
    func sendDatagram(_ memo : DatagramMemo) {
        let message = Message(mti: MTI.Datagram, source: memo.srcNode.id, destination: memo.destNode.id, data: memo.data)
        
        // TODO: Make a record of memo for reply
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
