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
    }

    struct Item: Hashable {
        let name: String?
        let deadline: String?
        let isDone: Bool

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
            let sortMenu = UIMenu(title: "Sort", children: getSortMenus(currentDescriptor))
            sortBarButton.menu = sortMenu
        }
    }

    lazy var fetchedResultsController: NSFetchedResultsController<Todo> = {

        let _controller: NSFetchedResultsController<Todo> = dataManager.getFetchedResultController(with: [currentDescriptor.rawValue])
        _controller.delegate = self
        return _controller
    }()

    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    var currentDescriptor: SortDescriptor = .deadline
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
        let newMenuActions = getSortMenus(descriptor)
        let newMenu = sortBarButton.menu?.replacingChildren(newMenuActions)
        sortBarButton.menu = nil
        sortBarButton.menu = newMenu
    }

    func getSortMenus(_ newDescriptor: SortDescriptor) -> [UIAction] {
        currentDescriptor = newDescriptor
        return [
            UIAction(title: "Date", state: currentDescriptor == .deadline ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.menuAction(.deadline)
            },
            UIAction(title: "Title", state: currentDescriptor == .title ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.menuAction(.title)
            },
            UIAction(title: "Status", state: currentDescriptor == .done ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
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

    func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let _ = Section(rawValue: indexPath.section) else {
                fatalError("Unknown section")
            }

            return collectionView.dequeueConfiguredReusableCell(using: self.configuredListCell(), for: indexPath, item: item)
        }
    }

    func updateSnapshot() {
        let sections = Section.allCases
        let items = (fetchedResultsController.fetchedObjects ?? []).map { Item($0) }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(sections)
        snapshot.appendItems(items)
        dataSource.apply(snapshot, animatingDifferences: true)
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
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updateSnapshot()
    }
}
