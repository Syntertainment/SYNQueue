//
//  ConsoleLogger.swift
//  SYNQueueDemo
//

import Foundation
import SYNQueue

import Foundation

func log(_ level: LogLevel, _ msg: String) {
    return ConsoleLogger().log(level, msg)
}

public class ConsoleLogger: SYNQueueLogProvider {
    
    public func log(_ level: LogLevel, _ msg: String) {
        print("[\(level.toString())] \(msg)")
    }
}
