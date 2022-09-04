//
//  QueueTest.swift
//  
//
//  Created by Bob Jacobsen on 9/4/22.
//

import XCTest
@testable import OpenlcbLibrary

final class QueueTest: XCTestCase {

    func testOperations() throws {
        var collection = Queue<Int>()

        XCTAssertTrue(collection.isEmpty)
        XCTAssertEqual(collection.dequeue(), nil)
        XCTAssertEqual(collection.peek(), nil)

        collection.enqueue(8)
        collection.enqueue(12)
        
        XCTAssertFalse(collection.isEmpty)
        
        XCTAssertEqual(collection.dequeue(), 8)
        XCTAssertEqual(collection.peek(), 12)
        XCTAssertEqual(collection.dequeue(), 12)
        XCTAssertTrue(collection.isEmpty)
    }

}
