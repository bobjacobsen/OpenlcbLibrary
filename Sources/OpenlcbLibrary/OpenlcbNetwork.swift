//
//  OpenlcbNetwork.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation
import os

#if canImport(UIKit)
import UIKit
#endif

/// Provides a common base implementation of an OpenLCB/LCC network using this package.
/// Configures a working OpenlcbLibrary subsystem.
public class OpenlcbNetwork : ObservableObject, CustomStringConvertible { // class to use @Published

    @Published public private(set) var remoteNodeStore : RemoteNodeStore

    @Published public var clockModel0 : ClockModel          // 0 in case more are added later, maniuplated by ClockView
 
    @Published public private(set) var throttleModel0 : ThrottleModel    // 0 in case more are added later // TODO: allow multiple throttles e.g. on macOS, with a single Roster
    
    @Published public private(set) var turnoutModel0 : TurnoutModel      // 0 in case more are added later
    
    @Published public private(set) var consistModel0 : ConsistModel      // 0 in case more are added later // TODO: Allow independent consisting views e.g. on macOS

    public var description : String { "OpenlcbNetwork w \(remoteNodeStore.nodes.count)"}

    internal let linkLayer : CanLink   // link to OpenLCB network; GridConnect-over-TCP implementation here.
    
    let localNode : Node      // the node that's implemented here
    let localNodeID : NodeID  // ID of the node implemented here
    
    var localNodeStore : LocalNodeStore
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "OpenlcbLibrary")
        
    let dservice : DatagramService
    public let mservice : MemoryService // needed for `CdCdiView`

    /// Initialize a basic system
    /// - Parameter defaultNodeID: NodeiID for this program
    public init(localNodeID : NodeID) {
        
        self.localNodeID = localNodeID
        localNode = Node(localNodeID)  // i.e. 0x05_01_01_01_03_01; user responsible for uniqueness of value
        
        linkLayer = CanLink(localNodeID: localNodeID)

        localNodeStore   = LocalNodeStore()
        remoteNodeStore  = RemoteNodeStore(localNodeID: localNodeID)
        clockModel0 = ClockModel()
        throttleModel0 = ThrottleModel(linkLayer)
        turnoutModel0 = TurnoutModel()
        consistModel0 = ConsistModel(linkLayer: linkLayer)
        dservice = DatagramService(linkLayer)
        mservice = MemoryService(service: dservice)

        // stored values initialized, 'self' available below here
        OpenlcbNetwork.logger.info("OpenlcbLibrary init")
        throttleModel0.openlcbNetwork = self
        turnoutModel0.network = self
    }
    
    /// Iniitialize and optionally add sample data for SwiftUI preview
    /// - Parameter sample: Iff true, add the sample nodes.
    public convenience init(sample: Bool) {
        self.init(localNodeID: NodeID(0x05_01_01_01_03_01))
        OpenlcbNetwork.logger.info("OpenlcbLibrary init(Bool)")
        if (sample) {
            createSampleData()
        }
    }
    
    /// This method will set up a system with
    ///   - A CAN-protocol Telnet connection
    ///   - defaultNode, a  local node in a local ``NodeStore``
    ///   - A ``remoteNodeStore`` that will contain every node the implementation sees
    ///
    public func configureCanTelnet(_ canPhysicalLayer : CanPhysicalLayer) { // pass in either a real or mock physical layer
        
        // local node has limited capability
        localNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,  // needed to receive replies to memory requests
                                  PIP.EVENT_EXCHANGE_PROTOCOL,
                                  PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL])
        
        // Define the SNIP identification for this node
        localNode.snip.manufacturerName = "Ardenwood.us"
        let dictionary = Bundle.main.infoDictionary!
        if let version : String = dictionary["CFBundleDisplayName"] as? String {
            localNode.snip.userProvidedDescription = version
            localNode.snip.modelName = "Full \(version) App"
        } else {
            localNode.snip.userProvidedDescription = "OpenlcbLibrary"
            localNode.snip.modelName = "Full OpenlcbLibrary App"
        }
        localNode.snip.softwareVersion  = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "<Unknown>"

#if canImport(UIKit)
        // iOS case - requires User Assigned Device Name entitlement to work in iOS 16 and later
        localNode.snip.userProvidedNodeName = UIDevice.current.name
        localNode.snip.softwareVersion  = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "<Unknown>"
        localNode.snip.hardwareVersion  = UIDevice.current.systemVersion  // holds current OS version
#else
        // macOS case
        if let deviceName = Host.current().localizedName {
            localNode.snip.userProvidedNodeName = deviceName
        } else {
            localNode.snip.userProvidedNodeName = "Some Mac"
        }
        localNode.snip.softwareVersion  = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "<Unknown>"
        let osVersionBlock = ProcessInfo.processInfo.operatingSystemVersion
        let major = osVersionBlock.majorVersion
        let minor = osVersionBlock.minorVersion
        let patch = osVersionBlock.patchVersion
        let osVersionString = "\(major).\(minor).\(patch)"
        localNode.snip.hardwareVersion  = osVersionString // holds current OS version
#endif
        
        localNode.snip.updateSnipDataFromStrings()    // load the SNIP strings we entered into the SNIP data store

        localNodeStore.store(localNode)               // define the node for this program
        
        // connect the physical -> link layers using the CAN-overTCP form (Native Telnet not yet available)
        linkLayer.linkPhysicalLayer(canPhysicalLayer)
        
        // create processors
        let rprocessor : Processor = RemoteNodeProcessor(linkLayer) // track effect of messages on Remote Nodes

        let lprocessor : Processor = LocalNodeProcessor(linkLayer)  // track effect of messages on Local Node

        let cprocessor : ClockProcessor = ClockProcessor(self, linkLayer, [clockModel0])   // clock processor doesn't affect node status
        clockModel0.processor = cprocessor

        let pprocessor : Processor = PrintingProcessor(printingProcessorPublishLine) // Publishes to SwiftUI
        
        let tprocessor : Processor = ThrottleProcessor(linkLayer, model: throttleModel0)
        
        // TODO: With this setup, only messages from the network are sent to pprocessor and displayed.
        
        // install processors
        remoteNodeStore.processors = [                        rprocessor]
        localNodeStore.processors =  [pprocessor, dservice,             lprocessor, cprocessor, tprocessor, consistModel0]
 
        // register listener here to process the node stores without copying them
        linkLayer.registerMessageReceivedListener(processMessageFromLinkLayer)

    }
    
    /// Look up the SNIP node name from the RemoteNodeStore
    /// - Parameter nodeId: NodeID of node to locate
    /// - Returns: Node name from SNIP information or "" if none
    func lookUpNodeName(for nodeId: NodeID) -> String {
        if let node = remoteNodeStore.lookup(nodeId) {
            return node.snip.userProvidedNodeName
        } else {
            return ""
        }
    }
    
    /// Process an incoming message across all the nodes in the remote node store.
    /// Does a publish operation if any of the nodes indicate a significant change.
    /// - Parameter message: Incoming message to process
    func processMessageFromLinkLayer(_ message: Message) {
        var publish = false
        
        publish = localNodeStore.invokeProcessorsOnNodes(message: message) || publish // always run invoke Processsors on nodes
        if remoteNodeStore.checkForNewNode(message: message) {
            remoteNodeStore.createNewRemoteNode(message: message)
            publish = true
        }
        publish = remoteNodeStore.invokeProcessorsOnNodes(message: message) || publish // always run invoke Processsors on nodes
        
        if publish {
            OpenlcbNetwork.logger.debug("publish change due to \(message, privacy: .public)")
            self.objectWillChange.send()
        }
    }
    
    /// Produce a specified event on the OpenLCB/LCC network.
    /// This sends a global message that's marked as coming from this program's node.
    /// - Parameter eventID: Event ID to be produced
    public func produceEvent(eventID: EventID) {
        let msg = Message(mti: .Producer_Consumer_Event_Report, source: linkLayer.localNodeID, data: eventID.toArray())
        sendMessage(msg)
    }
    
    /// Application has gone to .inactive state
    /// Send a `Link_Layer_Quiesced` MTI to inform application
    public func appInactive() {
        OpenlcbNetwork.logger.info("appInactive sends Quiesce")
        let msg = Message(mti: .Link_Layer_Quiesce, source: linkLayer.localNodeID)
        processMessageFromLinkLayer(msg)
    }
    
    /// Send a message to the network
    /// - Parameter message: Message to forward to network
    public func sendMessage(_ message: Message) {
        linkLayer.sendMessage(message)
    }
    
    /// Cause a remote node to "identify" itself by lighting its transmit LED
    /// Works by doing a VerifyNodeIdNumberAddressed request to the node
    public func identify(node : Node ) {
        let messageVerify  = Message(mti:.Verify_NodeID_Number_Addressed, source: linkLayer.localNodeID, destination: node.id)
        sendMessage(messageVerify)
    }
    
    /// Requests that a specific remote node update its SNIP information (basic text description).
    /// Sends an addressed SNIP request message to do that.
    /// - Parameter node: Addressed Node
    public func refreshNode(node : Node ) {
        node.snip = SNIP()
        let messagePIP  = Message(mti:.Protocol_Support_Inquiry, source: linkLayer.localNodeID, destination: node.id)
        sendMessage(messagePIP)
        let messageSNIP = Message(mti: .Simple_Node_Ident_Info_Request, source: linkLayer.localNodeID, destination: node.id)
        sendMessage(messageSNIP)
    }
    
    /// Cause all nodes to identify themselves, refreshing the node store.
    /// Sends a Verify Node Global to do that
    public func refreshAllNodes() {
        let messageVerify = Message(mti: .Verify_NodeID_Number_Global, source: linkLayer.localNodeID)
        sendMessage(messageVerify)
    }
    
    internal var sampleNode = Node(NodeID(0x01_01_01_01_01_01))  // minimal initialization, will be fleshed out in ``createSampleData``
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
    /// - Parameter canPhysicalLayer: Physical layer object to start the link-up process
    public func bringLinkUp(_ canPhysicalLayer : CanPhysicalLayer) {
        canPhysicalLayer.physicalLayerUp()
    }
}
