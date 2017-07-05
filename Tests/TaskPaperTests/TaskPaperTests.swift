import XCTest
@testable import TaskPaper

class TaskPaperTests: XCTestCase {
	
	func testBenchmark() {
		let str = "one:\n\t- two\n\t- three\n four five six seven eight nine\n\t- ten"
		var input = str
		
		for _ in 0..<73000 {
			input += str
		}
		
		measure {
			let _ = TaskPaper(input)
		}
	}
	
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        //XCTAssertEqual(TaskPaper().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
