//
//  SNIPTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class SNIPTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitialValue() {
        let snip = SNIP()
        XCTAssertEqual(snip.hardwareVersion, "", "Not nil")
    }
    
    func testGetString() {
        var s = SNIP() // init to all zeros
        s.data = Array(repeating: 0x41, count: 253)
        s.data[4] = 0
        XCTAssertEqual(s.getString(first : 1, maxLength : 5),"AAA")
  
        s.data = Array(repeating: 0x41, count: 253)  // no trailing zero
        XCTAssertEqual(s.getString(first : 1, maxLength : 5),"AAAAA")
    }

    func testLoadAndGetShort() {
        var s = SNIP() // init to all zeros
        s.data = Array(repeating: 0x41, count: 253)

        s.addData(data : [4, 0x41, 0x42, 0x43, 0]) // version + "ABC"
        XCTAssertEqual(s.data[3], 0x43)
        
        s.addData(data : [0x44, 0x45, 0x46, 0]) // DEF
        XCTAssertEqual(s.data[7], 0x46)
        
        s.addData(data : [0x31, 0x45, 0x46, 0]) // 1EF
        s.addData(data : [0x32, 0x45, 0x46, 0])
        s.addData(data : [2])                   // 2nd version string
        s.addData(data : [0x33, 0x45, 0x46, 0])
        s.addData(data : [0x34, 0x45, 0x46, 0])

        XCTAssertEqual(s.getString(n: 0),"ABC")
        XCTAssertEqual(s.getString(n: 1),"DEF")
        XCTAssertEqual(s.getString(n: 2),"1EF")
        XCTAssertEqual(s.getString(n: 3),"2EF")
        XCTAssertEqual(s.getString(n: 4),"3EF")
        XCTAssertEqual(s.getString(n: 5),"4EF")

        XCTAssertEqual(s.manufacturerName,"ABC")
        XCTAssertEqual(s.modelName,"DEF")
        XCTAssertEqual(s.hardwareVersion,"1EF")
        XCTAssertEqual(s.softwareVersion,"2EF")
        XCTAssertEqual(s.userProvidedNodeName,"3EF")
        XCTAssertEqual(s.userProvidedDescription,"4EF")

    }

    func testCharacterDecode() {
        // This checks how we're converting strings to byte arrays
        let str1 = "1234567890"
        
        let first3Bytes = Data(str1.utf8.prefix(3))
        XCTAssertEqual(first3Bytes.count, 3)
        XCTAssertEqual(first3Bytes[0], 0x31)
        
        let first20Bytes = Data(str1.utf8.prefix(20))
        XCTAssertEqual(first20Bytes[0], 0x31)
    }
    
    func testLoadStrings() {
        var s = SNIP() // init to all zeros

        s.manufacturerName = "ABC"
        s.modelName = "DEF"
        s.hardwareVersion = "1EF"
        s.softwareVersion = "2EF"
        s.userProvidedNodeName = "3EF"
        s.userProvidedDescription = "4EF"

        s.updateSnipDataFromStrings()
        
        XCTAssertEqual(s.getString(n: 0),"ABC")
        XCTAssertEqual(s.getString(n: 1),"DEF")
        XCTAssertEqual(s.getString(n: 2),"1EF")
        XCTAssertEqual(s.getString(n: 3),"2EF")
        XCTAssertEqual(s.getString(n: 4),"3EF")
        XCTAssertEqual(s.getString(n: 5),"4EF")
    }
    
    func testReturnStrings() {
        var s = SNIP() // init to all zeros

        s.manufacturerName = "ABC"
        s.modelName = "DEF"
        s.hardwareVersion = "1EF"
        s.softwareVersion = "2EF"
        s.userProvidedNodeName = "3EF"
        s.userProvidedDescription = "4EF"

        s.updateSnipDataFromStrings()

        let result = s.returnStrings()
        
        XCTAssertEqual(result[0], 4)
        
        XCTAssertEqual(result[1], 0x41)
        XCTAssertEqual(result[2], 0x42)
        XCTAssertEqual(result[3], 0x43)
        XCTAssertEqual(result[4], 0)

        XCTAssertEqual(result[5], 0x44)
        XCTAssertEqual(result[6], 0x45)
        XCTAssertEqual(result[7], 0x46)
        XCTAssertEqual(result[8], 0)

        XCTAssertEqual(result[ 9], 0x31)
        XCTAssertEqual(result[10], 0x45)
        XCTAssertEqual(result[11], 0x46)
        XCTAssertEqual(result[12], 0)

        XCTAssertEqual(result[13], 0x32)
        XCTAssertEqual(result[14], 0x45)
        XCTAssertEqual(result[15], 0x46)
        XCTAssertEqual(result[16], 0)

        XCTAssertEqual(result[17], 2)

        XCTAssertEqual(result[18], 0x33)
        XCTAssertEqual(result[19], 0x45)
        XCTAssertEqual(result[20], 0x46)
        XCTAssertEqual(result[21], 0)

        XCTAssertEqual(result[22], 0x34)
        XCTAssertEqual(result[23], 0x45)
        XCTAssertEqual(result[24], 0x46)
        XCTAssertEqual(result[25], 0)
    }
    
    func testName() {
        var s = SNIP() // init to all zeros
        s.userProvidedNodeName = "test 123"
        s.updateSnipDataFromStrings()
        s.updateStringsFromSnipData()
        XCTAssertEqual(s.userProvidedNodeName, "test 123")
    }
    
    func testConvenienceCtor() {
        let s = SNIP("mfgName", "model", "hVersion", "sVersion", "uName", "uDesc")
            
        XCTAssertEqual(s.manufacturerName, "mfgName")
        XCTAssertEqual(s.modelName, "model")
        XCTAssertEqual(s.hardwareVersion, "hVersion")
        XCTAssertEqual(s.softwareVersion, "sVersion")
        XCTAssertEqual(s.userProvidedNodeName, "uName")
        XCTAssertEqual(s.userProvidedDescription, "uDesc")
    }
}
