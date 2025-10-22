//
//  CDClipboardItem+CoreDataProperties.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//
//

import Foundation
import CoreData


extension CDClipboardItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDClipboardItem> {
        return NSFetchRequest<CDClipboardItem>(entityName: "CDClipboardItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var type: String?
    @NSManaged public var content: Data?

}

extension CDClipboardItem : Identifiable {

}
