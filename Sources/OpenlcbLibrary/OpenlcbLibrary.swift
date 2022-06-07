public struct OpenlcbLibrary {

    let defaultNode : Node
    public init() {
        defaultNode = Node(NodeID(0x05_01_01_01_03_01))
        defaultNode.pipSet = Set([PIP.DATAGRAM_PROTOCOL,
                               PIP.MEMORY_CONFIGURATION_PROTOCOL,
                               PIP.SIMPLE_NODE_IDENTIFICATION_PROTOCOL,
                               PIP.EVENT_EXCHANGE_PROTOCOL])

        //defaultNode = tempNode
    }
}
