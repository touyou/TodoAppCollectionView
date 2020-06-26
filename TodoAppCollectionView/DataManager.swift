//
//  DataManager.swift
//  TodoAppCollectionView
//
//  Created by 藤井陽介 on 2020/06/26.
//

import Foundation
import CoreData

class DataManager {

    static let shared: DataManager = DataManager()

    private var persistentContainer: NSPersistentContainer!

    init() {

        persistentContainer = NSPersistentContainer(name: "TodoAppCollectionView")
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }

    func create<T: NSManagedObject>() -> T {

        let context = persistentContainer.viewContext
        let object = NSEntityDescription.insertNewObject(forEntityName: String(describing: T.self), into: context) as! T
        return object
    }

    func delete<T: NSManagedObject>(_ object: T) {

        let context = persistentContainer.viewContext
        context.delete(object)
    }

    func saveContext() {

        let context = persistentContainer.viewContext

        do {

            try context.save()
        } catch {

            print("Failed save context: \(error)")
        }
    }

    func getFetchedResultController<T: NSManagedObject>(with descriptor: [String] = []) -> NSFetchedResultsController<T> {

        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.sortDescriptors = descriptor.map { NSSortDescriptor(key: $0, ascending: true) }
        return NSFetchedResultsController<T>(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    }
}
