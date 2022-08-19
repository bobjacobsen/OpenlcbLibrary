//
//  PrintingProcessorTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class PrintingProcessorTest: XCTestCase {
  
    var result : String = ""
    let node = Node(NodeID(12))

    override func setUpWithError() throws {
        result = ""
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitializationComplete() {
        let handler = { (data: String)  in
            self.result = data
        }
        let processor = PrintingProcessor(handler)
        let msg = Message(mti : MTI.Initialization_Complete, source : NodeID(12))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "00.00.00.00.00.0C: Initialization Complete ")
    }
    
    func testConsumerRangeIdentified() {
        // eventually, this will handle all MTI types, but here we check for one not coded yet
        let handler = { (data: String)  in
            self.result = data
        }
        let processor = PrintingProcessor(handler)
        let msg = Message(mti : MTI.Consumer_Range_Identified, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "00.00.00.00.00.0C: Consumer Range Identified ")
   }

    func testProducerConsumerEventReport() {
        // check unaddressed MTI
        let handler = { (data: String)  in
            self.result = data
        }
        let processor = PrintingProcessor(handler)
        let msg = Message(mti : MTI.Producer_Consumer_Event_Report, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "00.00.00.00.00.0C: Producer Consumer Event Report ")
    }

    func testLinkDown() {
        // check unaddressed MTI
        let handler = { (data: String)  in
            self.result = data
        }
        let processor = PrintingProcessor(handler)
        let msg = Message(mti : MTI.Link_Level_Down, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "Internal Message: Link Level Down ")
    }

}
