//
//  AppDelegate.swift
//  authreq
//
//  Created by Akos Szente on 13/11/2017.
//  Copyright © 2017 Akos Szente. All rights reserved.
//

import UIKit
import UserNotifications
import LocalAuthentication
import CoreData
import Piano

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    struct Shared {
        static let keypair: EllipticCurveKeyPair.Manager = {
            EllipticCurveKeyPair.logger = { print($0) }
            let publicAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleAlwaysThisDeviceOnly, flags: [])
            let privateAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly, flags: [.privateKeyUsage])
            
            let config = EllipticCurveKeyPair.Config(
                publicLabel: "info.szente.authreq.public",
                privateLabel: "info.szente.authreq.private",
                operationPrompt: "Sign transaction",
                publicKeyAccessControl: publicAccessControl,
                privateKeyAccessControl: privateAccessControl,
                token: .secureEnclaveIfAvailable)
            return EllipticCurveKeyPair.Manager(config: config)
        }()
    }

    var backgroundSessionCompletionHandler: (() -> Void)?
    
    var window: UIWindow?
    
    public var registeredForPushNotifications = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        do {
            //try Shared.keypair.deleteKeyPair()
            let publicKey = try Shared.keypair.publicKey().data().PEM
            print("Public key \(publicKey)")
        }
        catch let error {
            print("Error \(error)")
        }
        
        if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject] {
            let aps = notification["aps"] as! [String: AnyObject]
            print("got it");
            print(aps);
            (window?.rootViewController as? UITabBarController)?.selectedIndex = 1
        }
        UNUserNotificationCenter.current().delegate = self
        
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let controller = masterNavigationController.topViewController as! MasterViewController
        controller.managedObjectContext = self.persistentContainer.viewContext
        NotificationCenter.default.addObserver(self, selector: #selector(requestSuccessful), name: Notification.Name("SignatureRequestSuccessful"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(requestUnsuccessful), name: Notification.Name("SignatureRequestUnsuccessful"), object: nil)
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        let message = url.host?.removingPercentEncoding
        
        guard let bdata = message else {return false}
        guard let data = Data(base64Encoded: bdata) else { return false }
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String: AnyObject]
            {
                guard let aps = jsonArray["aps"] as? [String: AnyObject] else { return false }
                _ = SignatureRequest.createFromAps(aps: aps)
            }
        } catch let error as NSError {
            print(error)
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("Removing all notifications")
        
        if(!registeredForPushNotifications) {
            registeredForPushNotifications = true
            registerForPushNotifications()
        }
        
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        self.saveContext()
    }
    
    // MARK: - Split view
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.detailItem == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }

    func registerForPushNotifications() {
        print("registerForPushNotifications - requestAuthorization")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            (granted, error) in
            print("Permission granted: \(granted)")
            
            guard granted else { return }

            let allowAction = UNNotificationAction(identifier: "allowaction",
                                                  title: "✅ Allow",
                                                  options: [UNNotificationActionOptions.authenticationRequired])

            let declineAction = UNNotificationAction(identifier: "declineaction",
                                                  title: "❌ Deny",
                                                  options: [])

            let moreinfoAction = UNNotificationAction(identifier: "moreinfoaction",
                                                    title: "More Information...",
                                                    options: [.foreground])


            let challengeCategory = UNNotificationCategory(identifier: "challengecategory",
                                                      actions: [allowAction, declineAction, moreinfoAction],
                                                      intentIdentifiers: [],
                                                      options: [])

            UNUserNotificationCenter.current().setNotificationCategories([challengeCategory])
            self.getNotificationSettings()
        }
    }
    
    func getNotificationSettings() {
        print("getNotificationSettings - start")
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                print("getNotificationSettings - calling registerForRemoteNotifications")
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        
        let token = tokenParts.joined()
        UserDefaults.standard.set(token, forKey: "token")
        print("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let aps = userInfo["aps"] as! [String: AnyObject]
        print("Received notification in foreground: ")
        print(aps)
        
        _ = SignatureRequest.createFromAps(aps: aps)
        
        if(application.applicationState == UIApplicationState.inactive)
        {
            print("Inactive")
            //Show the view with the content of the push
            completionHandler(  .newData)
            
        }else if (application.applicationState == UIApplicationState.background){
            
            print("Background")
            //Refresh the local model
            completionHandler(.newData)
            
        }else{
            
            print("Active")
            //Show an in-app banner
            completionHandler(.newData)
        }
    }
    
    func declineAction(aps: [String: AnyObject]) {
        let request = SignatureRequest.createFromAps(aps: aps)
        request?.decline()
    }
    
    func allowAction(aps: [String: AnyObject]) {
        let request = SignatureRequest.createFromAps(aps: aps)
        _ = request?.signOnMainThread()
    }
    
    func moreInfoAction(aps: [String: AnyObject]) {
        guard let request = SignatureRequest.createFromAps(aps: aps) else {
            return
        }
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        
        if let controller = masterNavigationController.topViewController as? MasterViewController {
            controller.showDetailViewForItem(request: request)
        }
    }
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "authreq")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
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
    
    @objc func requestUnsuccessful() {
        let symphony: [Piano.Note] = [
            .sound(.file(name: "failure", extension: "caf")),
            .hapticFeedback(.notification(.failure))
        ]
        
        Piano.play(symphony)
    }
    
    @objc func requestSuccessful() {
        let symphony: [Piano.Note] = [
            .sound(.file(name: "success", extension: "caf")),
            .hapticFeedback(.notification(.success))
        ]
        
        Piano.play(symphony)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo
        
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            completionHandler()
            return;
        }
        
        if(response.actionIdentifier == "allowaction") {
            allowAction(aps: aps)
        }  else if(response.actionIdentifier == "declineaction") {
            declineAction(aps: aps)
        } else {
            moreInfoAction(aps: aps)
        }
        
        print("actionIdentifier: " + response.actionIdentifier + ", url: ")
        
        completionHandler()
    }
}

