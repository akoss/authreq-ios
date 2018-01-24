//
//  SignatureRequest+CoreDataClass.swift
//  authreq
//
//  Created by Akos Szente on 23/01/2018.
//  Copyright © 2018 Akos Szente. All rights reserved.
//
//

import Foundation
import CoreData
import UIKit
import UserNotifications
import LocalAuthentication

@objc(SignatureRequest)
public class SignatureRequest: NSManagedObject {
    
    static func getRecordForHash(hash: String) -> SignatureRequest? {

        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return nil
        }

        let moc = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SignatureRequest")
        fetchRequest.predicate = NSPredicate(format: "hashcalc == %@", hash)
        
        do {
            let fetched = try moc.fetch(fetchRequest) as! [SignatureRequest]
            if(fetched.count > 0) {
                print("(SignatureRequest already exists!)")
                return fetched[0]
            }
        } catch {
            fatalError("Failed to fetch employees: \(error)")
            return nil
        }
        print("(SignatureRequest doesn't already exist)")
        return nil
    }
    
    func calculateHash() -> String? {
        return SignatureRequest.calculateHashFor(body: self.push_text!, title: self.push_title!, subtitle: self.push_subtitle!, category: self.push_category!, response_url: self.response_url!, message_id: String(self.message_id), short_title: self.short_title!, nonce: self.nonce!, signature: self.srv_signature!, expiry: String(self.expiry))
    }
    
    static func calculateHashFor(body: String, title: String, subtitle: String, category: String, response_url: String, message_id: String, short_title: String, nonce: String, signature: String, expiry: String) -> String? {
     
        let jsonObject: NSMutableDictionary = NSMutableDictionary()
        
        jsonObject.setValue(body, forKey: "body")
        jsonObject.setValue(subtitle, forKey: "subtitle")
        jsonObject.setValue(category, forKey: "category")
        jsonObject.setValue(response_url, forKey: "response_url")
        jsonObject.setValue(message_id, forKey: "message_id")
        jsonObject.setValue(short_title, forKey: "short_title")
        jsonObject.setValue(nonce, forKey: "nonce")
        jsonObject.setValue(signature, forKey: "signature")
        jsonObject.setValue(expiry, forKey: "expiry")
        
        let jsonData: Data
        
        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions()) as Data
            let jsonString = NSString(data: jsonData as Data, encoding: String.Encoding.utf8.rawValue)! as String
            print("json string: " + jsonString)
            return jsonData.sha256().base64EncodedString()
        } catch _ {
            return nil
        }
    }
    
    static func getExistingElement(aps: [String: AnyObject]) -> SignatureRequest? {
        return nil
    }
    
    static func createFromAps(aps: [String: AnyObject]) -> SignatureRequest? {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return nil
        }

        guard let alertDict = aps["alert"] as? [String:String] else {
            NSLog("alertDict not a dictionary")
            return nil
        }
        
        guard let additional_data = aps["additional_data"] as? [String: AnyObject] else {
            print("additional_data not found")
            return nil
        }
        
        
        guard let category = aps["category"] as? String else {
            print("category not found")
            return nil
        }

        guard let nonce = additional_data["nonce"] as? String else {
            print("nonce not found")
            return nil
        }
        print("NONCE: " + nonce)
        
        guard let signature = additional_data["signature"] as? String else {
            print("signature not found")
            return nil
        }
        guard let response_url = additional_data["response_url"] as? String else {
            print("response_url not found")
            return nil
        }
        
        guard let short_title = additional_data["short_title"] as? String else {
            print("short_title not found")
            return nil
        }
        
        guard let message_id = additional_data["message_id"] as? NSInteger else {
            print("message_id not found")
            return nil
        }
        
        guard let expiry = additional_data["expiry"] as? NSInteger else {
            print("expiry not found")
            return nil
        }
        
        guard let push_text = alertDict["body"] else {
            print("alert body not found")
            return nil
        }

        guard let title = alertDict["title"] else {
            print("alert title not found")
            return nil
        }
        
        guard let subtitle = alertDict["subtitle"] else {
            print("alert subtitle not found")
            return nil
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        let entity =
            NSEntityDescription.entity(forEntityName: "SignatureRequest",
                                       in: managedContext)!
        
        let request = NSManagedObject(entity: entity,
                                      insertInto: managedContext)
        
        let hash = SignatureRequest.calculateHashFor(body: push_text, title: title, subtitle: subtitle, category: category, response_url: response_url, message_id: String(message_id), short_title: short_title, nonce: nonce, signature: signature, expiry: String(expiry))
        
        let existingRecord = SignatureRequest.getRecordForHash(hash: hash!)
        if(existingRecord != nil) {
            return existingRecord
        }
        
        print("beginning save")
        
        request.setValue(push_text, forKeyPath: "push_text")
        request.setValue(title, forKeyPath: "push_title")
        request.setValue(subtitle, forKeyPath: "push_subtitle")
        request.setValue(category, forKeyPath: "push_category")
        
        request.setValue(response_url, forKeyPath: "response_url")
        request.setValue(message_id, forKeyPath: "message_id")
        request.setValue(short_title, forKeyPath: "short_title")
        request.setValue(nonce, forKeyPath: "nonce")
        
        request.setValue(signature, forKeyPath: "srv_signature")
        request.setValue(Date() as NSDate, forKeyPath: "timestamp")
        request.setValue(expiry, forKeyPath: "expiry")
        
        request.setValue(0, forKeyPath: "reply_status")
        
        print("HasH: " + hash!)
        
        request.setValue(hash, forKeyPath: "hashcalc")
        
        do {
            try managedContext.save()
            return request as? SignatureRequest
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            return nil
        }
        
    }
    
    func decline() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Request Declined"
        content.subtitle = self.push_subtitle!
        content.body = self.push_text!

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "successConfirmation", content: content, trigger: trigger)
        
        center.add(request)
    }
    
    func sign() -> Bool {
        let content = UNMutableNotificationContent()
        var toReturn = true
        do {
            guard let digest = self.nonce?.data(using: .utf8) else {
                print("Unable to create nonce")
                return false
            }
            
            let pem = try AppDelegate.Shared.keypair.publicKey().data().PEM
            
            let context: LAContext! = LAContext()
            
            let signature = try AppDelegate.Shared.keypair.sign(digest, hash: .sha256, context: context)
            
            
            let newAlertBody = self.push_text! + "\n\n" + "Nonce: " + self.nonce! + "\n\nSignature: " + signature.base64EncodedString() + "\n\n" + "Public key: " + pem
            

            UIPasteboard.general.string = newAlertBody
            
            try AppDelegate.Shared.keypair.verify(signature: signature, originalDigest: digest, hash: .sha256)
            try printVerifySignatureInOpenssl(manager: AppDelegate.Shared.keypair, signed: signature, digest: digest, shaAlgorithm: "sha256")
            
            content.title = "✅ Allowed"
            content.subtitle = self.push_subtitle!
            content.body = self.push_text!
        } catch {
            print("Error: \(error)")
            content.title = "⚠️ Please open authreq to continue"
            content.body = self.push_title! + " - " + self.push_subtitle!
            content.badge = 1
            toReturn = false
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "successConfirmation", content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        
        center.add(request) { (error) in
            print(error ?? "")
        }
        
        return toReturn
    }
}
