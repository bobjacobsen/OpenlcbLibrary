//
//  ThrottleProcessorTest.swift
//  
//
//  Created by Bob Jacobsen on 6/18/22.
//

import XCTest
@testable import OpenlcbLibrary

final class ThrottleProcessorTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPCERmatch() throws {
        let node1 = Node(NodeID(1))
        let model = ThrottleModel()
        
        let put = ThrottleProcessor(nil, model: model)
        
        let pcerMatch =   Message(mti:.Producer_Consumer_Event_Report, source: NodeID(10), data: [1,1,0,0,0,0,3,3])
        let pcerNoMatch = Message(mti:.Producer_Consumer_Event_Report, source: NodeID(11), data: [1,1,0,0,0,0,3,0]) // mismatch in last entry
        
        put.process(pcerMatch, node1)
        put.process(pcerNoMatch, node1)
        
        XCTAssertEqual(model.trainNodes.count, 1)
        XCTAssertTrue(model.trainNodes.contains(NodeID(10)))
        XCTAssertFalse(model.trainNodes.contains(NodeID(11)))
    }
}
