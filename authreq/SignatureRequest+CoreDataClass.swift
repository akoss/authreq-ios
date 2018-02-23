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
import SwiftyRSA

@objc(SignatureRequest)
public class SignatureRequest: NSManagedObject, URLSessionDelegate {
    
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
        }
        print("(SignatureRequest doesn't already exist)")
        return nil
    }
    
    func checkSrvSignature() -> Bool {
        guard let sig = self.srv_signature else {
            return false
        }
        do {
            guard let asset = NSDataAsset(name: "publickey")?.data else {
                print("unable to gather public key asset")
                return false
            }
            
            guard let clearmessage = String(data: self.bencode() as Data, encoding: .utf8) else {
                print("unable to convert bencode to clearmessage")
                return false
            }
            print("clearmessage")
            print(clearmessage)
            
            guard let pem = String(data: asset, encoding: .utf8) else {
                print("unable to convert asset to pem")
                return false
            }
            
            let publicKey = try PublicKey(pemEncoded: pem)
            let signature = try Signature(base64Encoded: sig)
            let clear = try ClearMessage(string: clearmessage, using: .utf8)
            let isSuccessful = try clear.verify(with: publicKey, signature: signature, digestType: .sha256)
            
            return isSuccessful
        }
        catch let error as NSError {
            print(error)
            return false
        }
    }
    
    func calculateHash() -> String? {
        return SignatureRequest.calculateHashFor(body: self.push_text!, title: self.push_title!, subtitle: self.push_subtitle!, category: self.push_category!, response_url: self.response_url!, message_id: self.message_id, short_title: self.short_title!, nonce: self.nonce!, expiry: self.expiry)
    }
    
    func bencode() -> Data {
        return SignatureRequest.bencodeFor(body: self.push_text ?? "", title: self.push_title ?? "", subtitle: self.push_subtitle ?? "", category: self.push_category ?? "", response_url: self.response_url ?? "", message_id: self.message_id, short_title: self.short_title ?? "", nonce: self.nonce ?? "", expiry: self.expiry)
    }
    
    static func bencodeFor(body: String, title: String, subtitle: String, category: String, response_url: String, message_id: Int32, short_title: String, nonce: String, expiry: Int64) -> Data {
        return authreq.bencode(dict: ["body": body as AnyObject, "title": title as AnyObject, "subtitle": subtitle as AnyObject, "category": category as AnyObject, "response_url": response_url as AnyObject, "message_id": message_id as AnyObject, "short_title": short_title as AnyObject, "nonce": nonce as AnyObject, "expiry": expiry as AnyObject]) as Data
    }
    
    static func calculateHashFor(body: String, title: String, subtitle: String, category: String, response_url: String, message_id: Int32, short_title: String, nonce: String, expiry: Int64) -> String? {
        
        let bencoded = bencodeFor(body: body, title: title, subtitle: subtitle, category: category, response_url: response_url, message_id: message_id, short_title: short_title, nonce: nonce, expiry: expiry)
        
        print("BENCODED:")
        print(String(data: bencoded as Data, encoding: .utf8) ?? "")
        
        let hash = (bencoded as Data).sha256().base64EncodedString()
        
        print("hash: " + hash)
        return hash
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
        
        let hash = SignatureRequest.calculateHashFor(body: push_text, title: title, subtitle: subtitle, category: category, response_url: response_url, message_id: Int32(message_id), short_title: short_title, nonce: nonce, expiry: Int64(expiry))
        
        let existingRecord = SignatureRequest.getRecordForHash(hash: hash!)
        if(existingRecord != nil) {
            return existingRecord
        }
        
        let entity =
            NSEntityDescription.entity(forEntityName: "SignatureRequest",
                                       in: managedContext)!
        
        let request = NSManagedObject(entity: entity,
                                      insertInto: managedContext)
        
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
        
        guard let req = (request as? SignatureRequest) else {
            print("Failed to create object")
            return nil
        }
        
        if req.checkSrvSignature() != true {
            print("INVALID SIGNATURE")
            do {
                managedContext.delete(req)
                try managedContext.save()
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
                return nil
            }
            return nil
        }

        do {
            try managedContext.save()
            return req
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            return nil
        }
        
    }
    

    
    func isExpired() -> Bool {
        return (Double(self.expiry) < NSDate().timeIntervalSince1970)
    }
    
    static func updateExpiry() {
        print("updating expiry")
        let request = NSBatchUpdateRequest(entityName: "SignatureRequest")
        let predicate = NSPredicate(format: "expiry < %lf", NSDate().timeIntervalSince1970)
        request.predicate = predicate
        
        request.propertiesToUpdate = ["expired" : true]
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let moc = appDelegate.persistentContainer.viewContext
        
        do {
            _ = try moc.execute(request)
        } catch {
            fatalError("Failed to execute request: \(error)")
        }
    }
    
    func setReplyStatus(status: Int) {
        do {
            self.setValue(status, forKey: "reply_status")
            self.setValue(Date(), forKey: "reply_timestamp")
            
            try self.managedObjectContext?.save()
        } catch let error as NSError {
            print(error)
            return
        }
    }
    
    func getDigest() -> Data? {
        return self.bencode()
    }
    
    lazy var downloadsSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    func decline() {
        
        self.setReplyStatus(status: 2)
        
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Request Denied"
        content.subtitle = self.push_subtitle!
        content.body = self.push_text!
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "successConfirmation", content: content, trigger: trigger)
        
        center.add(request)
    }
    
    func signatureSuccessful(signature: Data, digest: Data) -> Bool {
        
        let newAlertBody = self.push_text! + "\n\n" + "Nonce: " + self.nonce! + "\n\nSignature: " + signature.base64EncodedString()
        UIPasteboard.general.string = newAlertBody
        
        let content = UNMutableNotificationContent()
        
        content.title = "✅ Allowed"
        content.subtitle = self.push_subtitle!
        content.body = self.push_text!
        
        content.sound = UNNotificationSound(named: "success.caf")
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "successConfirmation", content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        
        print("Posting notification")
        
        center.add(request) { (error) in
            print(error ?? "")
        }
        
        NotificationCenter.default.post(name: Notification.Name("SignatureRequestUpdated"), object: nil)
        
        return true
    }
    
    func signatureUnsuccessful(signature: Data?, digest: Data?) -> Bool {
        let content = UNMutableNotificationContent()
        
        content.title = "⚠️ Please open authreq to continue"
        content.body = self.push_title! + " - " + self.push_subtitle!
        content.badge = 1
        content.sound = UNNotificationSound(named: "failure.caf")
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: "failureConfirmation", content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        
        print("Posting notification")
        
        center.add(request) { (error) in
            print(error ?? "")
        }
        
        NotificationCenter.default.post(name: Notification.Name("SignatureRequestUpdated"), object: nil)
        
        return true
    }
    
    static func checkResponse(response: [String: Any]) -> Bool {
        guard let success = response["success"] as? Int else {
            return false
        }
        return (success == 1)
    }
    
    func continueSignature(signature: Data, digest: Data, isSynchronous: Bool) -> Bool {
        print("continuing signature")
        
        do {
            try AppDelegate.Shared.keypair.verify(signature: signature, originalDigest: digest, hash: .sha256)
            try printVerifySignatureInOpenssl(manager: AppDelegate.Shared.keypair, signed: signature, digest: digest, shaAlgorithm: "sha256")
        }
        catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            print("signature unsuccessful at continuingSignature: 2")
            _ = self.signatureUnsuccessful(signature: signature, digest: digest)
            return false
        }
        
        var publicKeyBase = (try? AppDelegate.Shared.keypair.publicKey().data().DER.base64EncodedString()) ?? "error fetching public key"
        publicKeyBase.insert("\n", at: publicKeyBase.index(publicKeyBase.startIndex, offsetBy: 64))
        
        let publicKeyString = "-----BEGIN PUBLIC KEY-----\n\(publicKeyBase)\n-----END PUBLIC KEY-----"
        
        guard let apistring = self.response_url else {
            print("No API url found")
            return false
        }
        
        guard let url = URL(string: apistring) else {
            print("Error: cannot create URL")
            return false
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        let json: [String: Any] = ["publickey": publicKeyString,
                                   "message_id": self.message_id,
                                   "signature": signature.map { String(format: "%02hhx", $0) }.joined(),
                                   "token": UserDefaults.standard.string(forKey: "token") ?? ""
                                    ]
        
        print("json: ")
        print(json)
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        urlRequest.httpBody = jsonData
        urlRequest.timeoutInterval = TimeInterval(15.0)
        
        if(isSynchronous) {
            let dict = self.downloadsSession.sendSynchronousRequest(urlRequest, timeout: 5.0) as [String:Any]?
            var answer = false
            if let response = dict as? [String: Any] {
                answer = SignatureRequest.checkResponse(response: response)
            }
            
            if(answer) {
                self.setReplyStatus(status: 1)
                _ = self.signatureSuccessful(signature: signature, digest: digest)
            } else {
                _ = self.signatureUnsuccessful(signature: signature, digest: digest)
                return false
            }
        } else {
            self.downloadsSession.dataTask(with: urlRequest, completionHandler: { (data, response, error) in
                var success = false
                if let error = error {
                    print(error)
                } else if let response = response {
                    print("RESPONSE: ")
                    print(response)
                    
                    if let responseData = data as? Data {
                        print(String(data: responseData, encoding: .utf8))
                        let jsonObject = try? JSONSerialization.jsonObject(with: responseData, options: [])
                        print("JSON Object")
                        print(jsonObject)
                        if let jsonDict = jsonObject as? [String: Any] {
                            success = SignatureRequest.checkResponse(response: jsonDict)
                        }
                    }
                }
                if(success) {
                    self.setReplyStatus(status: 1)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name("SignatureRequestSuccessful"), object: nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name("SignatureRequestUnsuccessful"), object: nil)
                    }
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("SignatureRequestUpdated"), object: nil)
                }
            }).resume()
        }
        
        print("continueSignature finished")
        return true
    }
    
    func getSignature() throws -> Data {
        let lacontext: LAContext! = LAContext()
        guard let digest = self.getDigest() else {
            throw "Missing text in unencrypted text field"
        }
        
        return try AppDelegate.Shared.keypair.sign(digest, hash: .sha256, context: lacontext)
    }
    
    func signOnMainThread() -> Bool {
        print("Starting signature (signOnMainThread())")
        
        if(self.checkSrvSignature() != true) {
            print("INVALID SIGNATURE")
            return false
        }
        
        guard let digest = self.getDigest() else {
            print("Unable to create nonce")
            return false
        }
        
        let signature: Data?
        do {
            signature = try self.getSignature()
        }
        catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            signature = nil
        }
        
        if let sig = signature {
            return self.continueSignature(signature: sig, digest: digest, isSynchronous: true)
        } else {
            return false
        }
    }
    
    func sign() -> Bool {
        print("Starting signature (sign())")
        
        if(self.checkSrvSignature() != true) {
            print("INVALID SIGNATURE")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("SignatureRequestUnsuccessful"), object: nil)
            }
            return false
        }
        
        DispatchQueue.roundTrip({
            guard let digest = self.getDigest() else {
                print("Unable to create nonce")
                throw "Missing text in unencrypted text field"
            }
            return digest
        }, thenAsync: { digest in
            return try self.getSignature()
        }, thenOnMain: { digest, signature in
            _ = self.continueSignature(signature: signature, digest: digest, isSynchronous: false)
        }, catchToMain: { error in
            print(error)
            print("signature unsuccessful at sign: 1")
            _ = self.signatureUnsuccessful(signature: nil, digest: nil)
        })
        return true
    }
}

