//
//  ViewController.swift
//  TodoAppCollectionView
//
//  Created by 藤井陽介 on 2020/06/26.
//

import UIKit
import CoreData

class ViewController: UIViewController {

    enum Section: Int, Hashable, CaseIterable {
        case main
        case outline
    }

    struct Item: Hashable {
        let name: String?
        let deadline: String?
        let isDone: Bool

        let hasChildren: Bool

        init(_ name: String, hasChildren: Bool = false) {
            self.name = name
            self.hasChildren = hasChildren

            self.isDone = false
            self.deadline = nil
        }

        init(_ todo: Todo) {
            self.name = todo.name
            self.isDone = todo.isDone

            if let deadline = todo.deadline {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd"
                self.deadline = dateFormatter.string(from: deadline)
            } else {
                self.deadline = nil
            }
            self.hasChildren = false
        }

        private let identifier = UUID()
    }

    enum SortDescriptor: String {
        case deadline
        case title = "name"
        case done = "isDone"
    }

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.backgroundColor = .systemGroupedBackground
            collectionView.collectionViewLayout = createLayout()
            collectionView.delegate = self
        }
    }
    @IBOutlet weak var sortBarButton: UIBarButtonItem! {
        didSet {
            let sortMenu = UIMenu(title: "Sort", children: getSortMenus())
            sortBarButton.menu = sortMenu
        }
    }

    lazy var fetchedResultsController: NSFetchedResultsController<Todo> = {

        let _controller: NSFetchedResultsController<Todo> = dataManager.getFetchedResultController(with: [currentDescriptor.rawValue])
        _controller.delegate = self
        return _controller
    }()

    var currentDescriptor: SortDescriptor = .deadline {
        didSet {
            let sortMenu = UIMenu(title: "Sort", children: getSortMenus())
            sortBarButton.menu = sortMenu
        }
    }

    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let todoSegueIdentifier = "todoSegue"
    let dataManager = DataManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavItem()
        configureDataSource()
        updateSnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        do {
            try fetchedResultsController.performFetch()
            updateSnapshot()
        } catch {
            print(error)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == todoSegueIdentifier {
            let viewController = segue.destination as! TodoViewController
            viewController.todo = sender as? Todo
        }
    }

    @IBAction func tappedAddButton(_ sender: Any) {
        performSegue(withIdentifier: todoSegueIdentifier, sender: nil)
    }

    func menuAction(_ descriptor: SortDescriptor) {
        let sortDescriptor = NSSortDescriptor(key: descriptor.rawValue, ascending: true)
        fetchedResultsController.fetchRequest.sortDescriptors = [sortDescriptor]
        try? fetchedResultsController.performFetch()
        updateSnapshot()
    }

    func getSortMenus() -> [UIAction] {
        return [
            UIAction(title: "Date", state: currentDescriptor == .deadline ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentDescriptor = .deadline
                self.menuAction(.deadline)
            },
            UIAction(title: "Title", state: currentDescriptor == .title ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentDescriptor = .title
                self.menuAction(.title)
            },
            UIAction(title: "Status", state: currentDescriptor == .done ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentDescriptor = .done
                self.menuAction(.done)
            },
        ]
    }
}

extension ViewController {
    func configureNavItem() {
        navigationItem.title = "Todo List"
        navigationItem.largeTitleDisplayMode = .always
    }

    func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let sectionKind = Section(rawValue: sectionIndex) else { return nil }

            if sectionKind == .main {
                return NSCollectionLayoutSection.list(using: .init(appearance: .insetGrouped), layoutEnvironment: layoutEnvironment)
            } else if sectionKind == .outline {
                let section = NSCollectionLayoutSection.list(using: .init(appearance: .sidebar), layoutEnvironment: layoutEnvironment)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10)
                return section
            } else {
                fatalError("Unknown section")
            }
        }

        return UICollectionViewCompositionalLayout(sectionProvider: sectionProvider)
    }

    func accessoriesForListCellItem(_ item: Item) -> [UICellAccessory] {
        return item.isDone ? [.checkmark()] : []
    }

    func leadingSwipeActionConfigurationForListCellItem(_ item: Item) -> UISwipeActionsConfiguration? {

        let editAction = UIContextualAction(style: .normal, title: nil) {
            [weak self] (_, _, completion) in
            guard let self = self else {
                completion(false)
                return
            }

            if let currentIndexPath = self.dataSource.indexPath(for: item) {
                let todo = self.fetchedResultsController.object(at: currentIndexPath)
                self.performSegue(withIdentifier: self.todoSegueIdentifier, sender: todo)
            }
            completion(true)
        }
        editAction.image = UIImage(systemName: "square.and.pencil")
        editAction.backgroundColor = .systemGreen

        return UISwipeActionsConfiguration(actions: [editAction])
    }

    func trailingSwipeActionConfigurationForListCellItem(_ item: Item) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: nil) {
            [weak self] (_, _, completion) in
            guard let self = self else {
                completion(false)
                return
            }

            if let currentIndexPath = self.dataSource.indexPath(for: item) {

                let alert = UIAlertController(title: "Delete", message: "Do you delete this todo?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                    let todo = self.fetchedResultsController.object(at: currentIndexPath)
                    self.dataManager.delete(todo)
                    completion(true)
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    completion(false)
                })
                self.present(alert, animated: true, completion: nil)
            } else {
                completion(true)
            }
        }
        deleteAction.image = UIImage(systemName: "trash")
        deleteAction.backgroundColor = .systemRed

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    func configuredListCell() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            var content = UIListContentConfiguration.valueCell()
            content.text = item.name
            content.secondaryText = item.deadline
            cell.contentConfiguration = content
            cell.accessories = self.accessoriesForListCellItem(item)
            cell.leadingSwipeActionsConfiguration = self.leadingSwipeActionConfigurationForListCellItem(item)
            cell.trailingSwipeActionsConfiguration = self.trailingSwipeActionConfigurationForListCellItem(item)
        }
    }

    func configuredOutlineHeaderCell() -> UICollectionView.CellRegistration<UICollectionViewListCell, String> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, String> { (cell, indexPath, title) in
            var content = cell.defaultContentConfiguration()
            content.text = title
            cell.contentConfiguration = content
            cell.accessories = [.outlineDisclosure(options: .init(style: .header))]
        }
    }

    func configuredOutlineCell() -> UICollectionView.CellRegistration<UICollectionViewListCell, Item> {
        return UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] (cell, indexPath, item) in
            guard let self = self else { return }
            var content = UIListContentConfiguration.valueCell()
            content.text = item.name
            content.secondaryText = item.deadline
            cell.contentConfiguration = content
            cell.accessories = self.accessoriesForListCellItem(item)
        }
    }

    func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let section = Section(rawValue: indexPath.section) else {
                fatalError("Unknown section")
            }
            switch section {
            case .main:
                return collectionView.dequeueConfiguredReusableCell(using: self.configuredListCell(), for: indexPath, item: item)
            case .outline:
                if item.hasChildren {
                    return collectionView.dequeueConfiguredReusableCell(using: self.configuredOutlineHeaderCell(), for: indexPath, item: item.name)
                } else {
                    return collectionView.dequeueConfiguredReusableCell(using: self.configuredOutlineCell(), for: indexPath, item: item)
                }
            }
        }
    }

    func updateSnapshot() {
        let sections = Section.allCases
        let fetchObjects = fetchedResultsController.fetchedObjects ?? []
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(sections)
        dataSource.apply(snapshot, animatingDifferences: false)

        var allSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
        var outlineSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()

        let items = fetchObjects.map { Item($0) }
        allSnapshot.append(items)

        let undoneRoot = Item("Undone", hasChildren: true)
        let doneRoot = Item("Done", hasChildren: true)
        outlineSnapshot.append([undoneRoot, doneRoot])
        let outlineItems = fetchObjects.map { Item($0) }
        let undoneItems = outlineItems.filter { !$0.isDone }
        let doneItems = outlineItems.filter { $0.isDone }
        outlineSnapshot.append(undoneItems, to: undoneRoot)
        outlineSnapshot.append(doneItems, to: doneRoot)

        dataSource.apply(allSnapshot, to: .main, animatingDifferences: false)
        dataSource.apply(outlineSnapshot, to: .outline, animatingDifferences: false)
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, canEditItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let data = fetchedResultsController.object(at: indexPath)
        data.isDone.toggle()
        dataManager.saveContext()
        if currentDescriptor == .done {
            try? fetchedResultsController.performFetch()
            updateSnapshot()
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updateSnapshot()
    }
}
