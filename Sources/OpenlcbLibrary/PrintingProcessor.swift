//
//  PrintingProcessor.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

// TODO: Does this display messages being sent?

import Foundation

///
/// Provide String versions of the received messages
///
struct PrintingProcessor : Processor {
    /// Pass in result routine to process output
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
        case    .Verify_NodeID_Number_Addressed,
                .Optional_Interaction_Rejected,
                .Terminate_Due_To_Error,
                .Protocol_Support_Inquiry,
                .Protocol_Support_Reply,
                .Identify_Events_Addressed,
                .Simple_Node_Ident_Info_Request,
                .Simple_Node_Ident_Info_Reply,
                .Datagram,
                .Datagram_Received_OK,
                .Datagram_Rejected :
            simpleAddressedMessage(message, node, dataString)
            
        case    .Initialization_Complete,
                .Initialization_Complete_Simple,
                .Verify_NodeID_Number_Global,
                .Verified_NodeID,
                .Identify_Consumer,
                .Identify_Producer,
                .Consumer_Range_Identified,
                .Consumer_Identified_Unknown,
                .Consumer_Identified_Active,
                .Consumer_Identified_Inactive,
                .Producer_Range_Identified,
                .Producer_Identified_Unknown,
                .Producer_Identified_Active,
                .Producer_Identified_Inactive,
                .Identify_Events_Global,
                .Learn_Event,
                .Producer_Consumer_Event_Report :
            simpleGlobalMessage(message, node, dataString)
        case    .Link_Level_Up, .Link_Level_Down, .New_Node_Seen, .Unknown :
            internalMessage(message, dataString)
        }
    }
    
    private func simpleAddressedMessage(_ message : Message, _ node : Node, _ dataString : String) {
        let name = message.mti.name.replacingOccurrences(of: "_", with: " ").capitalized
        result("\(message.source) \(name) \(dataString) to \(message.destination ?? NodeID(0))")
    }

    private func simpleGlobalMessage(_ message : Message, _ node : Node, _ dataString : String) {
        let name = message.mti.name.replacingOccurrences(of: "_", with: " ").capitalized
        result("\(message.source) \(name) \(dataString)")
    }
    
    private func internalMessage(_ message : Message, _ dataString : String) {
        let name = message.mti.name.replacingOccurrences(of: "_", with: " ").capitalized
        if message.mti.addressPresent() {
            result("Internal Message: \(name) \(dataString) to \(message.destination ?? NodeID(0))")
        } else {
            result("Internal Message: \(name) \(dataString)")
        }
    }
}

// ---------------------
// MARK: Directly print the result
// ---------------------
//  let handler : (_ : String) -> () = { (data: String)  in
//      print(data)
//      }
//  let pprocessor : Processor = PrintingProcessor(handler) // example that just prints info


// ---------------------
// MARK: Send to a View
// ---------------------
var lotsOfLinesToDisplay : [MonitorLine] = []

///
/// Pass this routine into init(..) to publish the messages to an ObservedObject
public func printingProcessorPublishLine(string : String) { // set this as ``result`` handler
    let NUMBER_OF_LINES = 100

    lotsOfLinesToDisplay.append(MonitorLine(line: string))
    
    // truncate to length
    if (lotsOfLinesToDisplay.count > NUMBER_OF_LINES) {
        lotsOfLinesToDisplay = Array(lotsOfLinesToDisplay[lotsOfLinesToDisplay.count-NUMBER_OF_LINES...lotsOfLinesToDisplay.count-1])
    }

    // publish to ObservedObject
    MonitorModel.sharedInstance.printingProcessorContentArray = lotsOfLinesToDisplay
}

/// ObservableObject publlishing the last `NIMBER_OF_LINES` of messages
public class MonitorModel: ObservableObject {
    public static let sharedInstance = MonitorModel()
    @Published public var printingProcessorContentArray: [MonitorLine] = [MonitorLine(line: "No Content Yet")]
}

/// Represents a single message line
public struct MonitorLine {
    public let id = UUID()
    public let line : String
}
