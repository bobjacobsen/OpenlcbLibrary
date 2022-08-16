//
//  OpenlcbLibrary.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

/// Configures a working OpenlcbLibrary subsystem.
///
import Foundation
import os

#if canImport(UIKit)
import UIKit
#endif

public class OpenlcbLibrary : ObservableObject, CustomStringConvertible { // class to use @Published

    let defaultNode : Node      // the node that's implemented here
    
    var localNodeStore : LocalNodeStore
    
    @Published public var remoteNodeStore : RemoteNodeStore

    @Published public var clock0 : Clock 
    
    let linkLevel : CanLink   // link to OpenLCB network; GridConnect-over-TCP implementation here.
    
    let logger = Logger(subsystem: "com.ardenwood.OpenlcbLibrary", category: "OpenlcbLibrary")
    
    public var description : String { "OpenlcbLibrary w \(remoteNodeStore.nodes.count)"}
    
    /// Initialize a basic system
    public init(defaultNodeID : NodeID) {
        
        defaultNode = Node(defaultNodeID)  // i.e. 0x05_01_01_01_03_01; user responsible for uniqueness of value
        
        localNodeStore   = LocalNodeStore()
        remoteNodeStore  = RemoteNodeStore(localNodeID: defaultNodeID)
        clock0 = Clock()
        
        linkLevel = CanLink(localNodeID: defaultNodeID)
        
        logger.info("OpenlcbLibrary init")
    }
    
    /// Iniitialize and add sample data for SwiftUI preview
    public convenience init(sample: Bool) {
        self.init(defaultNodeID: NodeID(0x05_01_01_01_03_01))
        logger.info("OpenlcbLibrary init(Bool)")
        if (sample) {
            createSampleData()
        }
    }
    /// The ``configureCanTelnet`` method will set up a system with
    ///   - A CAN-protocol Telnet connection
    ///   - ``defaultNode``, a  local node in a ``localNodeStore``
    ///   - A ``remoteNodeStore`` that will contain every node the implementation sees
    ///
    public func configureCanTelnet(_ canPhysicalLayer : CanPhysicalLayer) { // pass in either a real or mock physical layer
        
        // local node has limited capability
        defaultNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,  // needed to receive replies to memory requests
                                  PIP.EVENT_EXCHANGE_PROTOCOL,
                                  PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL])
        defaultNode.snip.manufacturerName = "Ardenwood.net"
        defaultNode.snip.modelName        = "OpenlcbLib"     // TODO: App name handling (as opposed to library name)
        defaultNode.snip.hardwareVersion  = "14"             // holds required iOS version
        defaultNode.snip.softwareVersion  = "0.0.1"          // TODO: Version number handling
        #if canImport(UIKit)
        defaultNode.snip.userProvidedNodeName = UIDevice.current.name
        #else
        if let deviceName = Host.current().localizedName {
            defaultNode.snip.userProvidedNodeName = deviceName
        } else {
            defaultNode.snip.userProvidedNodeName = "Some Mac"
        }
        #endif
        defaultNode.snip.userProvidedDescription = "OlcbTools app"
        defaultNode.snip.updateSnipDataFromStrings()

        localNodeStore.store(defaultNode)
        
        // connect the physical -> link layers using the CAN-overTCP form (Native Telnet not yet available)
        linkLevel.linkPhysicalLayer(canPhysicalLayer)
        
        // create processors
        let rprocessor : Processor = RemoteNodeProcessor(linkLevel) // track effect of messages on Remote Nodes
        let lprocessor : Processor = LocalNodeProcessor(linkLevel)  // track effect of messages on Local Node
        let dprocessor : Processor = DatagramProcessor(linkLevel)   // datagram processor doesn't affect node status
        let cprocessor : Processor = ClockProcessor(linkLevel, [clock0])   // clock processor doesn't affect node status

        let pprocessor : Processor = PrintingProcessor(printingProcessorPublishLine) // Publishes to SwiftUI
        // TODO: With this setup, only messages from the network are sent to pprocessor and displayed.
        
        // install processors
        remoteNodeStore.processors = [                        rprocessor]
        localNodeStore.processors =  [pprocessor, dprocessor,            lprocessor, cprocessor]
 
        // register listener here which will process the node stores without copying them
        linkLevel.registerMessageReceivedListener(processMessageFromLinkLevel)

    }
    
    func processMessageFromLinkLevel(_ message: Message) {
        let publish = true
        
        localNodeStore.invokeProcessorsOnNodes(message: message)
        remoteNodeStore.invokeProcessorsOnNodes(message: message)
        
        if publish {
            self.objectWillChange.send()
                // TODO: Every message publishes; make this less brute force with a return Bool from invokeProcessorsOnNodes?
                // TODO: Granularity too large, this is publishing entire node store and clock
        }
    }
    
    var sampleNode = Node(NodeID(0x01_01_01_01_01_01))  // minimal initialization, will be fleshed out in ``createSampleData``
    
    /// Load some sample nodes, but don't activate them - for use by testing of library clients
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
        
        for i : UInt64 in 0...4 {
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
    
    /// Once configuration (and optional sample data) is complete, bring the link up starting at the physical layer
    public func bringLinkUp(_ canPhysicalLayer : CanPhysicalLayer) {
        canPhysicalLayer.physicalLayerUp()
    }
}
