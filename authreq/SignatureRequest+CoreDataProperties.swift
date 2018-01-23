//
//  SignatureRequest+CoreDataProperties.swift
//  authreq
//
//  Created by Akos Szente on 23/01/2018.
//  Copyright © 2018 Akos Szente. All rights reserved.
//
//

import Foundation
import CoreData


extension SignatureRequest {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SignatureRequest> {
        return NSFetchRequest<SignatureRequest>(entityName: "SignatureRequest")
    }

    @NSManaged public var nonce: String?
    @NSManaged public var push_title: String?
    @NSManaged public var push_subtitle: String?
    @NSManaged public var push_category: String?
    @NSManaged public var push_text: String?
    @NSManaged public var message_id: Int32
    @NSManaged public var response_url: String?
    @NSManaged public var srv_signature: String?
    @NSManaged public var timestamp: NSDate?

}
