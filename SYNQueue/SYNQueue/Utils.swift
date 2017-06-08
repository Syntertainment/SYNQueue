//
//  Utils.swift
//  SYNQueue
//

import Foundation

func runInBackgroundAfter(_ seconds: TimeInterval, callback:@escaping ()->()) {
    let delta = DispatchTime.now() + Double(Int64(seconds) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
    DispatchQueue.global(qos: DispatchQoS.QoSClass.background).asyncAfter(deadline: delta, execute: callback)
}

func runOnMainThread(_ callback:@escaping ()->()) {
    DispatchQueue.main.async(execute: callback)
}

func toJSON(_ obj: Any) throws -> String? {
    let json = try JSONSerialization.data(withJSONObject: obj, options: [])
    return NSString(data: json, encoding: String.Encoding.utf8.rawValue) as String?
}

func fromJSON(_ str: String) throws -> Any? {
    if let json = str.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        let obj: Any = try JSONSerialization.jsonObject(with: json, options: .allowFragments) as Any
        return obj
    }
    return nil
}
