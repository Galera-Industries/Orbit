//
//  ClipboardTests.swift
//  OrbitTests
//
//  Created by Кирилл Исаев on 27.10.2025.
//

import XCTest

@testable import Orbit

final class ClipboardRepositoryTests: XCTestCase {
    
    var coreData: CoreDataMock!
    var repository: ClipboardRepositoryProtocol!
    
    override func setUp() {
        super.setUp()
        coreData = CoreDataMock(storageCount: 100)
        repository = ClipboardRepository(coreData: coreData)
    }
    
    override func tearDown() {
        repository = nil
        coreData = nil
        super.tearDown()
    }
    
    func testAddItem() {
        let item = ClipboardItem(type: .text, content: Data())
        
        repository.add(item)
        
        XCTAssertEqual(coreData.createItemResult.count, 1)
        XCTAssertEqual(coreData.createItemResult.first?.type, .text)
        XCTAssertEqual(repository.getAll().count, 1)
    }
    
    func testAddDuplicate() {
        let item = ClipboardItem(type: .text, content: Data())
        
        repository.add(item)
        repository.add(item)
        
        XCTAssertEqual(coreData.createItemResult.count, 1)
        XCTAssertEqual(coreData.createItemResult.first?.type, .text)
        XCTAssertEqual(repository.getAll().count, 1)
    }
    
    func testGetAll() {
        let item1 = ClipboardItem(type: .text, content: "First copied text".data(using: .utf8) ?? Data())
        let item2 = ClipboardItem(type: .text, content: "Second copied text".data(using: .utf8) ?? Data())
        let item3 = ClipboardItem(type: .text, content: "Third copied text".data(using: .utf8) ?? Data())
        
        repository.add(item1)
        repository.add(item2)
        repository.add(item3)
        
        let result = repository.getAll()
        
        XCTAssertNotEqual(result, [])
        XCTAssertEqual(result.count, 3)
    }
    
    func testGetByOrderSuccess() {
        let item1 = ClipboardItem(type: .text, content: "First copied text".data(using: .utf8) ?? Data())
        let item2 = ClipboardItem(type: .text, content: "Second copied text".data(using: .utf8) ?? Data())
        let item3 = ClipboardItem(type: .text, content: "Third copied text".data(using: .utf8) ?? Data())
        
        repository.add(item1)
        repository.add(item2)
        repository.add(item3)
        
        let itemByOrder = repository.getByOrder(1)
        
        XCTAssertNotNil(itemByOrder)
        XCTAssertEqual(itemByOrder, item2)
    }
    
    func testGetByOrderFailure() {
        let item1 = ClipboardItem(type: .text, content: "First copied text".data(using: .utf8) ?? Data())
        let item2 = ClipboardItem(type: .text, content: "Second copied text".data(using: .utf8) ?? Data())
        let item3 = ClipboardItem(type: .text, content: "Third copied text".data(using: .utf8) ?? Data())
        
        repository.add(item1)
        repository.add(item2)
        repository.add(item3)
        
        let itemByOrder = repository.getByOrder(10)
        
        XCTAssertNil(itemByOrder)
    }
    
    func testSearchNotEmpty() {
        let item1 = ClipboardItem(type: .text, content: "First copied text".data(using: .utf8) ?? Data())
        let item2 = ClipboardItem(type: .text, content: "Second copied text".data(using: .utf8) ?? Data())
        let item3 = ClipboardItem(type: .text, content: "Third copied text".data(using: .utf8) ?? Data())
        
        repository.add(item1)
        repository.add(item2)
        repository.add(item3)
        
        let result = repository.search("First")
        
        XCTAssertNotEqual(result, [])
        XCTAssertEqual(result.count, 1)
        guard let stringData = result.first?.content,
              let string = String(data: stringData, encoding: .utf8) else {
            XCTFail("Cant decode")
            return
        }
        XCTAssertEqual(string, "First copied text")
    }
    
    func testSearchMultipleReturn() {
        let item1 = ClipboardItem(type: .text, content: "First copied text".data(using: .utf8) ?? Data())
        let item2 = ClipboardItem(type: .text, content: "Second copied text".data(using: .utf8) ?? Data())
        let item3 = ClipboardItem(type: .text, content: "Third copied text".data(using: .utf8) ?? Data())
        
        repository.add(item1)
        repository.add(item2)
        repository.add(item3)
        
        let result = repository.search("copied")
        
        XCTAssertNotEqual(result, [])
        XCTAssertEqual(result.count, 3)
    }
    
    func testSearchEmpty() {
        let item1 = ClipboardItem(type: .text, content: "First copied text".data(using: .utf8) ?? Data())
        let item2 = ClipboardItem(type: .text, content: "Second copied text".data(using: .utf8) ?? Data())
        let item3 = ClipboardItem(type: .text, content: "Third copied text".data(using: .utf8) ?? Data())
        
        repository.add(item1)
        repository.add(item2)
        repository.add(item3)
        
        let result = repository.search("АБВГДЙКА")
        XCTAssertEqual(result, [])
    }
    
    func testClear() {
        let item1 = ClipboardItem(type: .text, content: "First copied text".data(using: .utf8) ?? Data())
        let item2 = ClipboardItem(type: .text, content: "Second copied text".data(using: .utf8) ?? Data())
        let item3 = ClipboardItem(type: .text, content: "Third copied text".data(using: .utf8) ?? Data())
        
        repository.add(item1)
        repository.add(item2)
        repository.add(item3)
        
        repository.clear()
        
        XCTAssertEqual(coreData.deleteItemResult.count, 3)
        XCTAssertEqual(repository.getAll().count, 0)
    }
    
    func testLimit() {
        for i in 0...101 {
            let item = ClipboardItem(type: .text, content: "\(i)".data(using: .utf8) ?? Data())
            repository.add(item)
        }
        XCTAssertEqual(coreData.deleteItemResult.count, 2)
        XCTAssertEqual(repository.getAll().count, 100)
    }
}
