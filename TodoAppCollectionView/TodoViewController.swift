//
//  TodoViewController.swift
//  TodoAppCollectionView
//
//  Created by 藤井陽介 on 2020/06/26.
//

import UIKit

class TodoViewController: UIViewController {
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!

    var todo: Todo?
    let dataManager = DataManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        if let todo = todo {
            titleTextField.text = todo.name
            datePicker.date = todo.deadline ?? Date()
        }
    }

    @IBAction func tappedSaveButton(_ sender: Any) {
        if todo == nil {
            todo = dataManager.create()
        }
        todo?.name = titleTextField.text
        todo?.deadline = datePicker.date
        dataManager.saveContext()

        let alert = UIAlertController(title: "Saved", message: "Saved todo.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [self] _ in
            navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true, completion: nil)
    }

    func configureNavItem() {
        navigationItem.title = "Edit todo"
        navigationItem.largeTitleDisplayMode = .always
    }
}
