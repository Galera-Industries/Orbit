//
//  CDClipboardItem+CoreDataProperties.swift
//  Orbit
//
//  Created by Кирилл Исаев on 08.11.2025.
//
//

import Foundation
import CoreData


extension CDClipboardItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDClipboardItem> {
        return NSFetchRequest<CDClipboardItem>(entityName: "CDClipboardItem")
    }

    @NSManaged public var content: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var pinned: Int32
    @NSManaged public var timestamp: Date?
    @NSManaged public var type: String?
    @NSManaged public var bundleID: String?
    @NSManaged public var appName: String?
    @NSManaged public var appIcon: Data?

}

extension CDClipboardItem : Identifiable {

}
