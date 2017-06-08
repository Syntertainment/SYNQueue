//
//  NSUserDefaultsSerializer.swift
//  SYNQueueDemo
//

import Foundation
import SYNQueue

class UserDefaultsSerializer : SYNQueueSerializationProvider {
    // MARK: - SYNQueueSerializationProvider Methods
    
    func serializeTask(_ task: SYNQueueTask, queueName: String) {
        if let serialized = task.toJSONString() {
            var stringArray: [String]
            if let curStringArray = UserDefaults.standard.stringArray(forKey: queueName) {
                stringArray = curStringArray
                stringArray.append(serialized)
            } else {
                stringArray = [serialized]
            }
            
            UserDefaults.standard.set(stringArray, forKey: queueName)
            UserDefaults.standard.synchronize()
        } else {
            log(.Error, "Failed to serialize task \(task.taskID) in queue \(queueName)")
        }
    }
    
    func deserializeTasks(_ queue: SYNQueue) -> [SYNQueueTask] {
        if  let queueName = queue.name,
            let stringArray = UserDefaults.standard.stringArray(forKey: queueName) {
            return stringArray
                .map { return SYNQueueTask(json: $0, queue: queue) }
                .filter { return $0 != nil }
                .map { return $0! }
        }
        return []
    }
    
    func removeTask(_ taskID: String, queue: SYNQueue) {
        if let queueName = queue.name {
            var curArray: [SYNQueueTask] = deserializeTasks(queue)
            curArray = curArray.filter { return $0.taskID != taskID }
            
            let stringArray = curArray
                .map { return $0.toJSONString() }
                .filter { return $0 != nil }
                .map { return $0! }
            
            UserDefaults.standard.set(stringArray, forKey: queueName)
            UserDefaults.standard.synchronize()
        }
    }
}
