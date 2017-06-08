//
//  Utils.swift
//  SYNQueueDemo
//

import Foundation
import SYNQueue
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


func arrayMax<T: Comparable>(_ array: [T]) -> T? {
    return array.reduce(array.first) { return $0 > $1 ? $0 : $1 }
}

func findIndex<T: Equatable>(_ array: [T], _ valueToFind: T) -> Int? {
    for (index, value) in array.enumerated() {
        if value == valueToFind {
            return index
        }
    }
    return nil
}

func runOnMainThread(_ callback: @escaping ()->()) {
    DispatchQueue.main.async(execute: callback)
}

func runOnMainThreadAfterDelay(_ delay:Double, _ callback: @escaping ()->()) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
        callback()
    })
}

func error(_ msg: String) -> NSError {
    return NSError(domain: "Error", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
}
