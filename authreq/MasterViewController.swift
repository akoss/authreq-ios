//
//  MasterViewController.swift
//  authreq-ios
//
//  Created by Akos Szente on 23/01/2018.
//  Copyright © 2018 Akos Szente. All rights reserved.
//

import UIKit
import CoreData
import Piano

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    var detailViewController: DetailViewController? = nil
    var managedObjectContext: NSManagedObjectContext? = nil
    var originalBackgroundView: UIView? = nil
    var noRecentsBackgroundView: UIView? = nil


    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rect = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height))
        noRecentsBackgroundView = NoRequestView(frame: rect)
        
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(settingsPressed(_:)))
        
        /*let button = UIButton.init(type: .custom)
        let image = UIImage(named: "settings")?.withRenderingMode(.alwaysTemplate)

        button.addTarget(self, action: #selector(settingsPressed(_:)), for: UIControlEvents.touchUpInside)
        
        button.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        button.setBackgroundImage(image, for: .normal)
        
        let barButton = UIBarButtonItem(customView: button)
        self.navigationItem.rightBarButtonItem = barButton*/
        UIApplication.shared.statusBarStyle = .lightContent
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
        
        originalBackgroundView = self.tableView.backgroundView
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.completeReload), name: Notification.Name("UIApplicationDidBecomeActiveNotification"), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        SignatureRequest.updateExpiry()
        completeReload()
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        pushNotificationPermissionGuard()
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func pushNotificationPermissionGuard() {
        if(UserDefaults.standard.bool(forKey: "beenRunBefore")) {
            if(!UIApplication.shared.isRegisteredForRemoteNotifications) {
                print("pushNotificationPermissionGuard: Not registered for remote notifications")
                let alertController = UIAlertController(title: "Authreq requires push notifications to work", message: "Push notifications are vital to authreq. Without them, we will not be able to relay signature requests.", preferredStyle: .alert)
                
                let actionSettings = UIAlertAction(title: "Settings", style: .default) { (action:UIAlertAction) in
                    DispatchQueue.main.async {
                        guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                            return
                        }
                        
                        if UIApplication.shared.canOpenURL(settingsUrl) {
                            UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                                print("pushNotificationPermissionGuard: Settings opened: \(success)") // Prints true
                            })
                            UserDefaults.standard.set(false, forKey: "beenRunBefore")
                            UserDefaults.standard.synchronize()
                        }
                    }
                }
                
                let actionCancel = UIAlertAction(title: "Skip", style: .cancel) { (action:UIAlertAction) in
                }
                
                alertController.addAction(actionSettings)
                alertController.addAction(actionCancel)
                self.present(alertController, animated: true, completion: nil)
            } else {
                print("pushNotificationPermissionGuard: Registered for remote notifications")
            }
        } else {
            print("pushNotificationPermissionGuard: First run")
            UserDefaults.standard.set(true, forKey: "beenRunBefore")
            UserDefaults.standard.synchronize()
        }
    }

    @objc
    func settingsPressed(_ sender: Any) {
        let alertController = UIAlertController(title: "New requests will appear automatically", message: "To enrol your device to a supported service, scan the provided QR code with your device's camera or log in from your iPhone and press 'Enrol to authreq'.", preferredStyle: .alert)
        
        let actionCancel = UIAlertAction(title: "OK", style: .cancel) { (action:UIAlertAction) in
        }
        
        /*let actionCamera = UIAlertAction(title: "Open Camera", style: .default) { (action:UIAlertAction) in
            UIApplication.shared.open(URL(string: "apple.com.camera://")!, options: [:], completionHandler: nil)
        }
        
        alertController.addAction(actionCamera)*/
        alertController.addAction(actionCancel)
        self.present(alertController, animated: true, completion: nil)
    }

    // MARK: - Segues
    
    func showDetailViewForItem(request: SignatureRequest) {
        detailViewController?.detailItem = request
        self.performSegue(withIdentifier: "showDetail", sender: request)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
            
            if let indexPath = tableView.indexPathForSelectedRow {
                let object = fetchedResultsController.object(at: indexPath)
                controller.detailItem = object
            }
            if let detail = sender as? SignatureRequest {
                controller.detailItem = detail
            }
        }
    }

    // MARK: - Table View
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let firstObject = self.fetchedResultsController.object(at: IndexPath(row: self.fetchedResultsController.sections![section].numberOfObjects-1, section: section))
        
        if((firstObject as SignatureRequest).expired) {
            return "Archive"
        } else {
            return nil
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        let result = fetchedResultsController.sections?.count ?? 0
        
        shouldShowEmptyMessage(result == 0)
        
        return result
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "signatureRequestCell", for: indexPath)
        let signatureRequest = fetchedResultsController.object(at: indexPath)
        configureCell(cell as! SignatureRequestTableViewCell, withSignatureRequest: signatureRequest )
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = fetchedResultsController.managedObjectContext
            context.delete(fetchedResultsController.object(at: indexPath))
                
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func configureCell(_ cell: SignatureRequestTableViewCell, withSignatureRequest signatureRequest: SignatureRequest) {

        cell.titleLabel?.text = signatureRequest.short_title
        cell.subtitleLabel?.text = signatureRequest.push_subtitle
        cell.accessoryType = .disclosureIndicator
        
        var isGray = true;
        
        if(signatureRequest.reply_status == 1) {
            cell.statusImageView.image = UIImage(named: "tick")
        } else if(signatureRequest.reply_status == 2) {
            cell.statusImageView.image = UIImage(named: "failure")
        } else if(signatureRequest.reply_status == 0) {
            if(signatureRequest.isExpired()) {
                cell.statusImageView.image = UIImage(named: "timeout")
            } else {
                cell.statusImageView.image = UIImage(named: "new")
                isGray = false;
            }
        }
        
        if(isGray) {
            cell.titleLabel?.textColor = UIColor.gray
            cell.subtitleLabel?.textColor = UIColor.lightGray
        } else {
            cell.titleLabel?.textColor = UIColor.black
            cell.subtitleLabel?.textColor = UIColor.lightGray
        }
    }

    // MARK: - Fetched results controller

    var fetchedResultsController: NSFetchedResultsController<SignatureRequest> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<SignatureRequest> = SignatureRequest.fetchRequest()
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
        let expiredSortDescriptor = NSSortDescriptor(key: "expired", ascending: true)
        
        fetchRequest.sortDescriptors = [expiredSortDescriptor, sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: "expired", cacheName: "Master")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
             // Replace this implementation with code to handle the error appropriately.
             // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             let nserror = error as NSError
             fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }    
    var _fetchedResultsController: NSFetchedResultsController<SignatureRequest>? = nil

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
            case .insert:
                tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            case .delete:
                tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            default:
                return
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        print("Change: " + String(describing: type))
        switch type {
            case .insert:
                tableView.insertRows(at: [newIndexPath!], with: .fade)
                let request = (anObject as! SignatureRequest)
                if !request.expired && request.reply_status == 0 {
                    let symphony: [Piano.Note] = [
                        .hapticFeedback(.impact(.medium)),
                        .sound(.system(.voicemail))
                    ]
                    Piano.play(symphony)
                }
            case .delete:
                tableView.deleteRows(at: [indexPath!], with: .fade)
            case .update:
                guard let cellToConfigure = tableView.cellForRow(at: indexPath!) as? SignatureRequestTableViewCell else {
                    return
                }
                configureCell(cellToConfigure, withSignatureRequest: anObject as! SignatureRequest)
            case .move:
                configureCell(tableView.cellForRow(at: indexPath!)! as! SignatureRequestTableViewCell, withSignatureRequest: anObject as! SignatureRequest)
                tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    @objc func completeReload() {
        print("Reloading tableView")
        _fetchedResultsController = nil
        let name = "Master" as String
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName:name)
        
        _fetchedResultsController = self.fetchedResultsController

        do {
            try _fetchedResultsController!.performFetch()
            self.tableView.reloadData()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    func shouldShowEmptyMessage(_ show: Bool) {
        if(show) {
            self.tableView.backgroundView = noRecentsBackgroundView;
            self.tableView.isScrollEnabled = false
            self.tableView.separatorStyle = .none;
        } else {
            self.tableView.backgroundView = originalBackgroundView;
            self.tableView.isScrollEnabled = true
            self.tableView.separatorStyle = .singleLine;
        }
    }
    
    /*
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
         // In the simplest, most efficient, case, reload the table view.
         tableView.reloadData()
     }
     */
}

