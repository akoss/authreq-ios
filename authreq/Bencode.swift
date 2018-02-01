//
//  Bencode.swift
//  authreq
//
//  Created by Akos Szente on 01/02/2018.
//  Copyright © 2018 Akos Szente. All rights reserved.
//

import Foundation

func decideToBencode(item : AnyObject) -> NSData? {
    if let bencodableData = item as? String {
        return bencode(s: bencodableData)
    } else if let bencodableData = item as? NSData {
        return bencode(d: bencodableData)
    } else if let bencodableData = item as? Int {
        return bencode(i: bencodableData)
    } else if let bencodableData = item as? Array<AnyObject> {
        return bencode(arr: bencodableData)
    } else if let bencodableData = item as? Dictionary<String, AnyObject> {
        return bencode(dict: bencodableData)
    }
    return nil
}

public func bencode(s : String) -> NSData {
    let data = NSMutableData()
    let str = "\(s.lengthOfBytes(using: String.Encoding.utf8)):"
    data.append(str.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
    data.append(s.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
    return data
}

public func bencode(d : NSData) -> NSData {
    let data = NSMutableData()
    let str = "\(d.length):"
    data.append(str.data(using:String.Encoding.utf8, allowLossyConversion: false)!)
    data.append(d as Data)
    return data
}

public func bencode(i : Int) -> NSData {
    let data = NSMutableData()
    let str = "i\(String(i))e"
    data.append(str.data(using:String.Encoding.utf8, allowLossyConversion: false)!)
    return data
}

public func bencode(arr : [AnyObject]) -> NSData {
    let data = NSMutableData()
    data.append("l".data(using:String.Encoding.utf8, allowLossyConversion: false)!)
    for item in arr {
        if let bencodedData = decideToBencode(item: item) {
            data.append(bencodedData as Data)
        }
    }
    data.append("e".data(using:String.Encoding.utf8, allowLossyConversion: false)!)
    return data
}

public func bencode(dict : [String:AnyObject]) -> NSData {
    let data = NSMutableData()
    data.append("d".data(using:String.Encoding.utf8, allowLossyConversion: false)!)
    
    let sortedKeys = dict.keys.sorted()
    for key in sortedKeys {
        data.append(decideToBencode(item: key as AnyObject)! as Data)
        if let value: AnyObject = dict[key] {
            if let bencodedData = decideToBencode(item: value) {
                data.append(bencodedData as Data)
            }
        }
    }
    
    data.append("e".data(using:String.Encoding.utf8, allowLossyConversion: false)!)
    return data
}
