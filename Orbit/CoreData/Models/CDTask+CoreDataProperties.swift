import Foundation
import CoreData

extension CDTask {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDTask> {
        return NSFetchRequest<CDTask>(entityName: "CDTask")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var tags: String?
    @NSManaged public var priority: Int32
    @NSManaged public var dueDate: Date?
    @NSManaged public var completed: Bool
    @NSManaged public var eventIdentifier: String?

}

extension CDTask : Identifiable {

}

