//
//  OpenlcbLibrary.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

/// Configures a working OpenlcbLibrary system.
///

public struct OpenlcbLibrary {

    let defaultNode : Node
    
    var localNodeStore : NodeStore
    var remoteNodeStore : RemoteNodeStore

    let canLink : CanLink
    
    public init() {
        defaultNode = Node(NodeID(0x05_01_01_01_03_01))
        
        localNodeStore   = NodeStore()
        remoteNodeStore  = RemoteNodeStore(localNodeStore: localNodeStore)
        
        canLink = CanLink()
    }
    
    /// The ``configureCanTelnet`` method will set up a system with
    ///   - A CAN-protocol Telnet connection
    ///   - ``defaultNode``, a  local node in a ``localNodeStore``
    ///   - A ``remoteNodeStore`` that will contain every node the implementation sees
    ///
    public func configureCanTelnet(_ canPhysicalLayer : CanPhysicalLayer) { // pass in either a real or mock physical layer
        
        // local node has limited capability
        defaultNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,  // needed to make memory requests
                               PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                               PIP.EVENT_EXCHANGE_PROTOCOL])
        defaultNode.snip.manufacturerName = "Ardenwood.net"
        defaultNode.snip.modelName        = "OpenlcbLib"
        defaultNode.snip.hardwareVersion  = "14"             // holds iOS version // TODO: rethink hardware version
        defaultNode.snip.softwareVersion  = "0.0"            // TODO: Version number handling
        defaultNode.snip.loadStrings()

        localNodeStore.store(defaultNode)
        
        // connect the physical -> link layers
        canLink.linkPhysicalLayer(canPhysicalLayer)
        
        canLink.registerMessageReceivedListener(localNodeStore.invokeProcessorsOnNodes)
        canLink.registerMessageReceivedListener(remoteNodeStore.invokeProcessorsOnNodes)

        // create processors
        let rprocessor : Processor = RemoteNodeProcessor(canLink) // track effect of messages on Remote Nodes
        let lprocessor : Processor = LocalNodeProcessor(canLink)  // track effect of messages on Local Node
        let dprocessor : Processor = DatagramProcessor(canLink)   // datagram processor doesn't affect node status
        // printing process, well, prints
        let handler : (_ : String) -> () = { (data: String)  in
            // TODO: do something print-like with ``data``
        }
        let pprocessor : Processor = PrintingProcessor(handler) // example of processor that extracts info from message

        // install processors
        remoteNodeStore.processors = [pprocessor,             rprocessor]
        localNodeStore.processors =  [pprocessor, dprocessor,            lprocessor]
        
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
        remoteNodeStore.store(node1)

        let node2 = Node(NodeID(0x02_02_02_02_02_02))
        node2.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                             PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                             PIP.EVENT_EXCHANGE_PROTOCOL])
        node2.snip.manufacturerName = "Sample Nodes"
        node2.snip.modelName        = "Node 2"
        node2.snip.hardwareVersion  = "HVersion 2"
        node2.snip.softwareVersion  = "SVersion 2"
        node2.snip.loadStrings()
        remoteNodeStore.store(node2)
    }
    
    /// Once configuration (and optional sample data) is complete, bring the link up
    public func bringLinkUp(_ canPhysicalLayer : CanPhysicalLayer) {
        canPhysicalLayer.physicalLayerUp()
    }
}
