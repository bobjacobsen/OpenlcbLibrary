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
        let msg = Message(mti : MTI.InitializationComplete, source : NodeID(12))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "NodeID 00.00.00.00.00.0C InitializationComplete ")
    }
    
    func testConsumerRangeIdentified() {
        // eventually, this will handle all MTI types, but here we check for one not coded yet
        let handler = { (data: String)  in
            self.result = data
        }
        let processor = PrintingProcessor(handler)
        let msg = Message(mti : MTI.ConsumerRangeIdentified, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "NodeID 00.00.00.00.00.0C ConsumerRangeIdentified ")
   }

    func testProducerConsumerEventReport() {
        // check unaddressed MTI
        let handler = { (data: String)  in
            self.result = data
        }
        let processor = PrintingProcessor(handler)
        let msg = Message(mti : MTI.ProducerConsumerEventReport, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "NodeID 00.00.00.00.00.0C ProducerConsumerEventReport ")
    }

    func testLinkDown() {
        // check unaddressed MTI
        let handler = { (data: String)  in
            self.result = data
        }
        let processor = PrintingProcessor(handler)
        let msg = Message(mti : MTI.LinkLevelDown, source : NodeID(12), destination : NodeID(13))
        
        processor.process(msg, node)
        
        XCTAssertEqual(result, "Internal Message: LinkLevelDown ")
    }

}
