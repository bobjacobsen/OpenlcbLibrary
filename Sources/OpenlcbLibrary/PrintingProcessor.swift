//
//  PrintingProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import Foundation

/// Provide String versions of the received messages
struct PrintingProcessor : Processor {
    /// Pass in something to process output
    public init ( _ result : @escaping ( _ : String) -> (), _ linkLayer: LinkLayer? = nil) {
        self.result = result
        self.linkLayer = linkLayer
    }
    let linkLayer : LinkLayer?
    var result : (_ : String) -> ()
    
    public func process( _ message : Message, _ node : Node ) {
        var dataString = ""
        for byte in message.data {
            dataString += "\(String(format:"%02X", byte)) "
        }
        switch message.mti {
        case    .VerifyNodeIDNumberAddressed,
                .VerifiedNodeID,
                .OptionalInteractionRejected,
                .TerminateDueToError,
                .ProtocolSupportInquiry,
                .ProtocolSupportReply,
                .IdentifyEventsAddressed,
                .SimpleNodeIdentInfoRequest,
                .SimpleNodeIdentInfoReply,
                .Datagram,
                .DatagramReceivedOK,
                .DatagramRejected :
            simpleAddressedMessage(message, node, dataString)
            
        case    .InitializationComplete,
                .InitializationCompleteSimple,
                .VerifyNodeIDNumberGlobal,
                .IdentifyConsumer,
                .IdentifyProducer,
                .ConsumerRangeIdentified,
                .ConsumerIdentifiedUnknown,
                .ConsumerIdentifiedActive,
                .ConsumerIdentifiedInactive,
                .ProducerRangeIdentified,
                .ProducerIdentifiedUnknown,
                .ProducerIdentifiedActive,
                .ProducerIdentifiedInactive,
               .IdentifyEventsGlobal,
                .LearnEvent,
                .ProducerConsumerEventReport :
            simpleGlobalMessage(message, node, dataString)
        case    .LinkLevelUp, .LinkLevelDown, .Unknown :
            internalMessage(message, dataString)
        }
    }
    
    private func simpleAddressedMessage(_ message : Message, _ node : Node, _ dataString : String) {
        result("\(message.source) \(message.mti) \(dataString)(\(message.destination ?? NodeID(0)))")
    }

    private func simpleGlobalMessage(_ message : Message, _ node : Node, _ dataString : String) {
        result("\(message.source) \(message.mti) \(dataString)")
    }
    
    private func internalMessage(_ message : Message, _ dataString : String) {
        result("Internal Message: \(message.mti) \(dataString)")
    }
}

// ---------------------
// for sending to a View
// ---------------------
var lotsOfLinesToDisplay : [MonitorLine] = [MonitorLine(line: "Initial Content")]

public func printingProcessorPublishLine(string : String) { // set this as ``result`` handler
    let NUMBER_OF_LINES = 100

    lotsOfLinesToDisplay.append(MonitorLine(line: string))
    
    // truncate to length
    if (lotsOfLinesToDisplay.count > NUMBER_OF_LINES) {
        lotsOfLinesToDisplay = Array(lotsOfLinesToDisplay[lotsOfLinesToDisplay.count-NUMBER_OF_LINES...lotsOfLinesToDisplay.count-1])
    }

    // publish to ObservedObject
    MonitorModel.sharedInstance.printingProcessorContentArray = lotsOfLinesToDisplay // was globaleVariable
}
public class MonitorModel: ObservableObject {
    public static let sharedInstance = MonitorModel()
    @Published public var printingProcessorContentArray: [MonitorLine] = [MonitorLine(line: "No Content Yet")]
}
public struct MonitorLine {
    public let id = UUID()
    public let line : String
}
