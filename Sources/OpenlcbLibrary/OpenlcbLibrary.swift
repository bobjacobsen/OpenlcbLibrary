//
//  OpenlcbLibrary.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

/// Configures a working OpenlcbLibrary system.
///

public struct OpenlcbLibrary {

    let defaultNode : Node
    
    public var localNodeStore : NodeStore
    public var remoteNodeStore : RemoteNodeStore

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
                               PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL])
        defaultNode.snip.manufacturerName = "Ardenwood.net"
        defaultNode.snip.modelName        = "OpenlcbLib"
        defaultNode.snip.hardwareVersion  = "14"             // holds iOS version // TODO: rethink hardware version
        defaultNode.snip.softwareVersion  = "0.0"            // TODO: Version number handling
        defaultNode.snip.userProvidedNodeName = "App with no name (yet)"
        defaultNode.snip.updateSnipDataFromStrings()

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
    
    var sampleNode = Node(NodeID(0x01_01_01_01_01_01))  // minimal initialization, will be fleshed out in ``createSampleData``
    
    /// Load some sample nodes, but don't activate them
    public func createSampleData() {
        // create two remote nodes
        sampleNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                             PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                             PIP.EVENT_EXCHANGE_PROTOCOL])
        sampleNode.snip.manufacturerName = "Sample Nodes"
        sampleNode.snip.modelName        = "Model Type 1"
        sampleNode.snip.hardwareVersion  = "HVersion 1"
        sampleNode.snip.softwareVersion  = "SVersion 1"
        sampleNode.snip.userProvidedNodeName = "User Node 1"
        sampleNode.snip.userProvidedDescription = "Not really much to say about node 1"
        sampleNode.snip.updateSnipDataFromStrings()
        sampleNode.snip.updateStringsFromSnipData()
        remoteNodeStore.store(sampleNode)

        let node2 = Node(NodeID(0x02_02_02_02_02_02))
        node2.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                             PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                             PIP.EVENT_EXCHANGE_PROTOCOL])
        node2.snip.manufacturerName = "Sample Nodes"
        node2.snip.modelName        = "Node Type 2"
        node2.snip.hardwareVersion  = "HVersion 2"
        node2.snip.softwareVersion  = "SVersion 2"
        node2.snip.userProvidedNodeName = "User Node 2"
        node2.snip.userProvidedDescription = "Node 2 is much like node 1, except it has a maximal length description that goes on and on"
        node2.snip.updateSnipDataFromStrings()
        node2.snip.updateStringsFromSnipData()
        remoteNodeStore.store(node2)
        
        // Leave 03,03,03,03,03,03 uncreated as that ID is used for testing
        
        for i : UInt64 in 0...30 {
            let nextID = NodeID(0x02_02_02_02_02_03).nodeId+i
            let nextNode = Node(NodeID(nextID))
            nextNode.snip.manufacturerName = "Auto Nodes"
            nextNode.snip.modelName        = "Node Type \(i)"
            nextNode.snip.hardwareVersion  = "HVersion  \(i)"
            nextNode.snip.softwareVersion  = "SVersion  \(i)"
            nextNode.snip.userProvidedNodeName = "Auto Node \(i)"
            nextNode.snip.userProvidedDescription = "Auto Node \(i) is really a node unto itself"
            nextNode.snip.updateSnipDataFromStrings()
            nextNode.snip.updateStringsFromSnipData()
            remoteNodeStore.store(nextNode)
        }
    }
    
    /// Once configuration (and optional sample data) is complete, bring the link up
    public func bringLinkUp(_ canPhysicalLayer : CanPhysicalLayer) {
        canPhysicalLayer.physicalLayerUp()
    }
}
