//
//  PrintingProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Provide String versions of the received messages
struct PrintingProcessor : Processor {
    /// Pass in something to process output
    public init (_ result : @escaping ( _ : String) -> ()) {
        self.result = result
    }
    var result : (_ : String) -> ()
    
    public func process( _ message : Message, _ node : Node) {
        switch message.mti {
        case    .VerifyNodeIDNumberAddressed,
                .VerifiedNodeID,
                .OptionalInteractionRejected,
                .TerminateDueToError,
                .ProtocolSupportInquiry,
                .ProtocolSupportReply,
                .ConsumerRangeIdentified,
                .ConsumerIdentifiedUnknown,
                .ConsumerIdentifiedActive,
                .ConsumerIdentifiedInactive,
                .ProducerRangeIdentified,
                .ProducerIdentifiedUnknown,
                .ProducerIdentifiedActive,
                .ProducerIdentifiedInactive,
                .IdentifyEventsAddressed,
                .SimpleNodeIdentInfoRequest,
                .SimpleNodeIdentInfoReply,
                .Datagram,
                .DatagramReceivedOK,
                .DatagramRejected :
            simpleAddressedMessage(message, node)
            
        case    .InitializationComplete,
                .VerifyNodeIDNumberGlobal,
                .IdentifyConsumer,
                .IdentifyProducer,
                .IdentifyEventsGlobal,
                .LearnEvent,
                .ProducerConsumerEventReport :
            simpleGlobalMessage(message, node)
        case    .LinkLevelUp, .LinkLevelDown, .Unknown :
            internalMessage(message)
        }
    }
    
    private func simpleAddressedMessage(_ message : Message, _ node : Node) {
        result("\(message.source) \(message.mti) (\(message.destination ?? NodeID(0)))")
    }

    private func simpleGlobalMessage(_ message : Message, _ node : Node) {
        result("\(message.source) \(message.mti)")
    }
    
    private func internalMessage(_ message : Message) {
        result("Internal Message: \(message.mti)")
    }
}
