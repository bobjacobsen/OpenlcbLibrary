//
//  OpenlcbLibrary.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

/// Configures a working OpenlcbLibrary system.
///

public struct OpenlcbLibrary {

    static let defaultNode : Node = Node(NodeID(0x05_01_01_01_03_01))
    
    static var remoteNodeStore  = NodeStore()
    static var localNodeStore   = NodeStore()
    
    static let canLink = CanLink()
    
    /// The ``configureCanTelnet`` method will set up a system with
    ///   - A CAN-protocol Telnet connection
    ///   - ``defaultNode``, a  local node in a ``localNodeStore``
    ///   - A ``remoteNodeStore`` that will contain every node the implementation sees
    ///
    public func configureCanTelnet(_ canPhysicalLayer : CanPhysicalLayer) { // pass in either a real or mock physical layer
        
        // local node has limited capability
        OpenlcbLibrary.defaultNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,  // needed to make memory requests
                               PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                               PIP.EVENT_EXCHANGE_PROTOCOL])
        OpenlcbLibrary.defaultNode.snip.manufacturerName = "Ardenwood.net"
        OpenlcbLibrary.defaultNode.snip.modelName        = "OpenlcbLib"
        OpenlcbLibrary.defaultNode.snip.hardwareVersion  = "14"             // holds iOS version // TODO: rethink hardware version
        OpenlcbLibrary.defaultNode.snip.softwareVersion  = "0.0"            // TODO: Version number handling

        OpenlcbLibrary.localNodeStore.store(OpenlcbLibrary.defaultNode)
        
        // connect the physical -> link layers
        OpenlcbLibrary.canLink.linkPhysicalLayer(canPhysicalLayer)
        
        // TODO: connection link -> message layers by registering NodeStore(s)
        OpenlcbLibrary.canLink.registerMessageReceivedListener(OpenlcbLibrary.localNodeStore.invokeProcessorsOnNodes)
        OpenlcbLibrary.canLink.registerMessageReceivedListener(OpenlcbLibrary.remoteNodeStore.invokeProcessorsOnNodes)

        // create processors
        let rprocessor : Processor = RemoteNodeProcessor(OpenlcbLibrary.canLink) // track effect of messages on Remote Nodes
        let lprocessor : Processor = LocalNodeProcessor(OpenlcbLibrary.canLink)  // track effect of messages on Local Node
        let dprocessor : Processor = DatagramProcessor(OpenlcbLibrary.canLink)   // datagram processor doesn't affect node status
        // printing process, well, prints
        let handler : (_ : String) -> () = { (data: String)  in
            // TODO: do something print-like with ``data``
        }
        let pprocessor : Processor = PrintingProcessor(handler) // example of processor that extracts info from message

        // install processors
        OpenlcbLibrary.remoteNodeStore.processors = [pprocessor,             rprocessor]
        OpenlcbLibrary.localNodeStore.processors =  [pprocessor, dprocessor,            lprocessor]
        
    }
    
    /// Load some sample nodes, but don't activate them
    public func createSampleData() {
        // create two remote nodes
        let node1 = Node(NodeID(0x01_01_01_01_01_01))
        node1.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                             PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                             PIP.EVENT_EXCHANGE_PROTOCOL])
        node1.snip.manufacturerName = "Sample Nodes"
        node1.snip.modelName        = "Node 1"
        node1.snip.hardwareVersion  = "HVersion 1"
        node1.snip.softwareVersion  = "SVersion 1"
        node1.snip.loadStrings()
        OpenlcbLibrary.remoteNodeStore.store(node1)

        let node2 = Node(NodeID(0x01_01_02_02_02_02))
        node2.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                             PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                             PIP.EVENT_EXCHANGE_PROTOCOL])
        node2.snip.manufacturerName = "Sample Nodes"
        node2.snip.modelName        = "Node 2"
        node2.snip.hardwareVersion  = "HVersion 2"
        node2.snip.softwareVersion  = "SVersion 2"
        node2.snip.loadStrings()
        OpenlcbLibrary.remoteNodeStore.store(node2)
    }
    
    /// Once configuration (and optional sample data) is complete, bring the link up
    public func bringLinkUp(_ canPhysicalLayer : CanPhysicalLayer) {
        canPhysicalLayer.physicalLayerUp()
    }
}
