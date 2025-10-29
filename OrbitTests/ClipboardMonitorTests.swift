//
//  ClipboardMonitorTests.swift
//  OrbitTests
//
//  Created by Кирилл Исаев on 29.10.2025.
//

import XCTest

@testable import Orbit

final class ClipboardMonitorTests: XCTestCase {
    
    var monitor: ClipboardMonitorMock!
    
    override func setUp() {
        super.setUp()
        monitor = ClipboardMonitorMock()
    }
    
    override func tearDown() {
        monitor = nil
        super.tearDown()
    }
    
    func testClipboardMonitorQueue() {
        var receivedItems: [ClipboardItem] = []
        monitor.onClipboardChange = { item in
            receivedItems.append(item)
        }
        monitor.startMonitoring()
        let items = (1...3).map { i in
            ClipboardItem(type: .text, content: "Item \(i)".data(using: .utf8)!)
        }
        monitor.enqueue(items)
        let expectation = XCTestExpectation(description: "Clipboard items processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(receivedItems.count, 3)
            XCTAssertEqual(String(data: receivedItems[0].content, encoding: .utf8), "Item 1")
            XCTAssertEqual(String(data: receivedItems[2].content, encoding: .utf8), "Item 3")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
