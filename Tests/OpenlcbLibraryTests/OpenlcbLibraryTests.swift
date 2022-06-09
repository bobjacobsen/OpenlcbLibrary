import XCTest
@testable import OpenlcbLibrary

final class OpenlcbLibraryTests: XCTestCase {
    
    func testCanSetup() {
        let lib = OpenlcbLibrary()
        lib.configureCanTelnet()
    }
    
}
