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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    struct Shared {
        static let keypair: EllipticCurveKeyPair.Manager = {
            EllipticCurveKeyPair.logger = { print($0) }
            let publicAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleAlwaysThisDeviceOnly, flags: [])
            let privateAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, flags: [.privateKeyUsage])
            
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
    
    var window: UIWindow?
    var context: LAContext! = LAContext()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        registerForPushNotifications()
        
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
        print("removing current notifications")
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        self.saveContext()
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            (granted, error) in
            print("Permission granted: \(granted)")
            
            guard granted else { return }

            let allowAction = UNNotificationAction(identifier: "allowaction",
                                                  title: "✅ Allow",
                                                  options: [UNNotificationActionOptions.authenticationRequired])

            let declineAction = UNNotificationAction(identifier: "declineaction",
                                                  title: "❌ Decline",
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
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
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
        print("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let aps = userInfo["aps"] as! [String: AnyObject]
        print("notification in foreground")
        print(aps)
    }
    
    func declineAction(aps: [String: AnyObject]) {
        
        let content = UNMutableNotificationContent()
        guard let alertDict = aps["alert"] as? [String:String] else {
            NSLog("alertDict not a dictionary")
            return
        }
        
        guard let alertSubtitle = alertDict["subtitle"] else {
            return
        }
        guard let alertbody = alertDict["body"] else {
            return
        }
        
        content.title = "Request Declined"
        content.subtitle = alertSubtitle
        content.body = alertbody
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "declineConfirmation", content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(request) { (error) in
            print(error)
        }
    }
    
    func allowAction(aps: [String: AnyObject]) {
        print(aps)
        let content = UNMutableNotificationContent()
        guard let alertDict = aps["alert"] as? [String:String] else {
            NSLog("alertDict not a dictionary")
            return
        }
        
        guard let additional_data = aps["additional_data"] as? [String: AnyObject] else {
            print("additional_data not found")
            return
        }
        
        guard let nonce = additional_data["nonce"] as? String else {
            return
        }
        
        print("NONCE: " + nonce)
        
        guard let alertSubtitle = alertDict["subtitle"] else {
            return
        }
        guard let alertBody = alertDict["body"] else {
            return
        }

        
        do {
            let pem = try Shared.keypair.publicKey().data().PEM
            print("PEM: " + pem)
            
            guard let digest = nonce.data(using: .utf8) else {
                return
            }
                
            let signature = try Shared.keypair.sign(digest, hash: .sha256, context: self.context)
            
            let newAlertBody = alertBody + "\n\n" + "Nonce: " + nonce + "\n\nSignature: " + signature.base64EncodedString() + "\n\n" + "Public key: " + pem
            print(newAlertBody)
            UIPasteboard.general.string = newAlertBody
            
            try Shared.keypair.verify(signature: signature, originalDigest: digest, hash: .sha256)
            try printVerifySignatureInOpenssl(manager: Shared.keypair, signed: signature, digest: digest, shaAlgorithm: "sha256")
            
            self.save(name: nonce)
            
            content.title = "✅ Allowed"
            content.subtitle = alertSubtitle
            content.body = newAlertBody
        } catch {
            print("Error: \(error)")
            content.title = "⚠️ Please open authreq to continue"
            content.body = alertSubtitle + " - " + alertBody
            content.badge = 1
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "successConfirmation", content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()

        center.add(request) { (error) in
            print(error)
        }
    }
    
    func save(name: String) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        let entity =
            NSEntityDescription.entity(forEntityName: "Request",
                                       in: managedContext)!
        
        let request = NSManagedObject(entity: entity,
                                     insertInto: managedContext)
        
        request.setValue(name, forKeyPath: "nonce")
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
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
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // 1
        let userInfo = response.notification.request.content.userInfo
        let aps = userInfo["aps"] as! [String: AnyObject]
        
        if(response.actionIdentifier == "allowaction") {
            allowAction(aps: aps);
        }  else if(response.actionIdentifier == "declineaction") {
            declineAction(aps: aps);
        }
        
        // 2
        print("actionIdentifier: " + response.actionIdentifier + ", url: ")
        
        completionHandler()
    }
}

