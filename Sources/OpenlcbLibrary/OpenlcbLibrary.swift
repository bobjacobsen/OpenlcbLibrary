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

    @Published public var clockModel0 : ClockModel
 
    @Published public var throttleModel0 : ThrottleModel

    public let linkLevel : CanLink   // link to OpenLCB network; GridConnect-over-TCP implementation here.
    
    let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "OpenlcbLibrary")
    
    public var description : String { "OpenlcbLibrary w \(remoteNodeStore.nodes.count)"}
    
    let dservice : DatagramService
    public let mservice : MemoryService // TODO: Needs to be encapsulated in a model, not free to CdiView

    /// Initialize a basic system
    public init(defaultNodeID : NodeID) {
        
        defaultNode = Node(defaultNodeID)  // i.e. 0x05_01_01_01_03_01; user responsible for uniqueness of value
        
        linkLevel = CanLink(localNodeID: defaultNodeID)

        localNodeStore   = LocalNodeStore()
        remoteNodeStore  = RemoteNodeStore(localNodeID: defaultNodeID)
        clockModel0 = ClockModel()
        throttleModel0 = ThrottleModel(linkLevel)
        dservice = DatagramService(linkLevel)
        mservice = MemoryService(service: dservice)

        // stored values initialized, 'self' available below here
        logger.info("OpenlcbLibrary init")
        throttleModel0.openlcbLibrary = self
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
        defaultNode.snip.modelName        = "OlcbTools"     // TODO: App name handling (as opposed to library name)
        defaultNode.snip.hardwareVersion  = "15.0"           // holds required iOS version
        defaultNode.snip.softwareVersion  = "0.0.1"          // TODO: Version number handling
        #if canImport(UIKit)
        // iOS case
        defaultNode.snip.userProvidedNodeName = UIDevice.current.name
        #else
        // macOS case
        if let deviceName = Host.current().localizedName {
            defaultNode.snip.userProvidedNodeName = deviceName
        } else {
            defaultNode.snip.userProvidedNodeName = "Some Mac"
        }
        #endif
        defaultNode.snip.userProvidedDescription = "Full OlcbTools App"
        defaultNode.snip.updateSnipDataFromStrings()

        localNodeStore.store(defaultNode)
        
        // connect the physical -> link layers using the CAN-overTCP form (Native Telnet not yet available)
        linkLevel.linkPhysicalLayer(canPhysicalLayer)
        
        // create processors
        let rprocessor : Processor = RemoteNodeProcessor(linkLevel) // track effect of messages on Remote Nodes

        let lprocessor : Processor = LocalNodeProcessor(linkLevel)  // track effect of messages on Local Node

        //let dservice = DatagramService(linkLevel)
        
        //let mservice = MemoryService(service: dservice)

        let cprocessor : Processor = ClockProcessor(linkLevel, [clockModel0])   // clock processor doesn't affect node status

        let pprocessor : Processor = PrintingProcessor(printingProcessorPublishLine) // Publishes to SwiftUI
        
        let tprocessor : Processor = ThrottleProcessor(linkLevel, model: throttleModel0)
        
        // TODO: With this setup, only messages from the network are sent to pprocessor and displayed.
        
        // install processors
        remoteNodeStore.processors = [                        rprocessor]
        localNodeStore.processors =  [pprocessor, dservice,             lprocessor, cprocessor, tprocessor]
 
        // register listener here which will process the node stores without copying them
        linkLevel.registerMessageReceivedListener(processMessageFromLinkLevel)

    }
    
    /// Look up the SNIP node name from the RemoteNodeStore
    // Because removeNodeStore is an active struct (for swiftui) you can't pass it to e.g. ThrottleModel at initialization time
    func lookUpNodeName(for nodeId: NodeID) -> String {
        // return the node ID if there's no SNIP information
        if let node = remoteNodeStore.lookup(nodeId) {
            return node.snip.userProvidedNodeName
        } else {
            return ""
        }
    }
    
    func processMessageFromLinkLevel(_ message: Message) {
        var publish = false
        
        publish = localNodeStore.invokeProcessorsOnNodes(message: message) || publish // always run invoke Processsors on nodes
        if remoteNodeStore.checkForNewNode(message: message) {
            remoteNodeStore.createNewRemoteNode(message: message)
            publish = true
        }
        publish = remoteNodeStore.invokeProcessorsOnNodes(message: message) || publish // always run invoke Processsors on nodes
        
        if publish {
            logger.debug("publish change due to \(message, privacy: .public)")
            self.objectWillChange.send()
        }
    }
    
    public func produceEvent(eventID: EventID) {
        let msg = Message(mti: .Producer_Consumer_Event_Report, source: linkLevel.localNodeID, data: eventID.toArray())
        linkLevel.sendMessage(msg)
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
