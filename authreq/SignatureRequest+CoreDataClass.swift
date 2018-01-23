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

@objc(SignatureRequest)
public class SignatureRequest: NSManagedObject {
    
    static func saveFromAps(aps: [String: AnyObject]) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }

        guard let alertDict = aps["alert"] as? [String:String] else {
            NSLog("alertDict not a dictionary")
            return
        }
        
        guard let additional_data = aps["additional_data"] as? [String: AnyObject] else {
            print("additional_data not found")
            return
        }
        
        
        guard (aps["category"] as? String) != nil else {
            print("category not found")
            return
        }

        guard let nonce = additional_data["nonce"] as? String else {
            print("nonce not found")
            return
        }
        print("NONCE: " + nonce)
        
        guard let signature = additional_data["signature"] as? String else {
            print("signature not found")
            return
        }
        guard let response_url = additional_data["response_url"] as? String else {
            print("response_url not found")
            return
        }
        
        guard let message_id = additional_data["message_id"] as? NSInteger else {
            print("message_id not found")
            return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        let entity =
            NSEntityDescription.entity(forEntityName: "SignatureRequest",
                                       in: managedContext)!
        
        let request = NSManagedObject(entity: entity,
                                      insertInto: managedContext)
        
        request.setValue(alertDict["body"], forKeyPath: "push_text")
        request.setValue(alertDict["title"], forKeyPath: "push_title")
        request.setValue(alertDict["subtitle"], forKeyPath: "push_subtitle")
        request.setValue(alertDict["category"], forKeyPath: "push_category")
        
        request.setValue(response_url, forKeyPath: "response_url")
        request.setValue(message_id, forKeyPath: "message_id")
        //request.setValue(hash, forKeyPath: "hash")
        request.setValue(nonce, forKeyPath: "nonce")
        
        request.setValue(signature, forKeyPath: "srv_signature")
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
        
    }
}
