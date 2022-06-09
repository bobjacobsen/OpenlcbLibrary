//
//  OpenlcbLibrary.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

/// Configures a working OpenlcbLibrary system.
///

public struct OpenlcbLibrary {

    static let defaultNode : Node = Node(NodeID(0x05_01_01_01_03_01))
    
    static let remoteNodeStore  = NodeStore()
    static let localNodeStore   = NodeStore()
    
    static let canLink = CanLink()
    static let canPhysicalLayer = CanPhysicalLayer()
    
    
    
    /// The ``configureCanTelnet`` method will set up a system with
    ///   - A CAN-protocol Telnet connection
    ///   - ``defaultNode``, a  local node in a ``localNodeStore``
    ///   - A ``remoteNodeStore`` that will contain every node the implementation sees
    ///
    public func configureCanTelnet() {
        OpenlcbLibrary.defaultNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                               PIP.MEMORY_CONFIGURATION_PROTOCOL,
                               PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                               PIP.EVENT_EXCHANGE_PROTOCOL])

        
        
    }
}
