//
//  SecondViewController.swift
//  authreq
//
//  Created by Akos Szente on 13/11/2017.
//  Copyright © 2017 Akos Szente. All rights reserved.
//

import UIKit
import CoreData

class SecondViewController: UIViewController, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    let cellReuseIdentifier = "cell"
    
    var requests: [NSManagedObject] = []
    
   /* func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as UITableViewCell!
        
        // set the text from the data model
        cell.textLabel?.text = "proba"
        
        return cell
    }
*/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        let fetchRequest =
            NSFetchRequest<NSManagedObject>(entityName: "Request")
        
        do {
            requests = try managedContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
}

// MARK: - UITableViewDataSource
extension SecondViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
            
            let request = requests[indexPath.row]
            let cell =
                tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier,
                                              for: indexPath)
            cell.textLabel?.text =
                request.value(forKeyPath: "nonce") as? String
            return cell
    }
}
