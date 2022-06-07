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
        
        /// Retrieve the datagram typre from a DatagramMemo.
        /// Returns -1 if there is no type specified, i.e. the datagram is empty
        func datagramType() -> Int {
            if data.count > 0 {
                return Int(data[0])
            } else {
                return -1
            }
        }
    }
    
    func sendDatagram(_ memo : DatagramMemo) {
        
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
