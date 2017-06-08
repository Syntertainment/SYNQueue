//
//  SYNQueueTests.swift
//  SYNQueueTests
//

import UIKit
import XCTest
@testable import SYNQueue

class SYNQueueTests: XCTestCase {
    
    var logger = ConsoleLogger()
    var serializer = UserDefaultsSerializer()
    let testTaskType = "testTaskType"
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        logger = ConsoleLogger()
        serializer = UserDefaultsSerializer()
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInitialization() {
        let name = randomQueueName()
        let queue = SYNQueue(queueName: name, maxConcurrency: 3, maxRetries: 2, logProvider: logger, serializationProvider: serializer) { (error: NSError?, task: SYNQueueTask) -> Void in
            //
        }
        XCTAssertNotNil(queue)
        XCTAssert(queue.name == name)
        XCTAssert(queue.maxConcurrentOperationCount == 3)
        XCTAssert(queue.maxRetries == 2)
        XCTAssertNotNil(queue.logProvider)
        XCTAssertNotNil(queue.serializationProvider)
        XCTAssertNotNil(queue.completionBlock)
    }
    
    func testTaskCompletion() {
        
        let taskCompletionExpectation = expectation(description: "taskCompletion")
        
        let queue = SYNQueue(queueName: randomQueueName(), maxConcurrency: 3, maxRetries: 2, logProvider: logger, serializationProvider: serializer) { (error: NSError?, task: SYNQueueTask) -> Void in
            taskCompletionExpectation.fulfill()
        }
        
        queue.addTaskHandler(testTaskType) { $0.completed(nil) }
        let task = SYNQueueTask(queue: queue, taskType: testTaskType)
        queue.addOperation(task)
        
        XCTAssert(queue.operationCount == 1)
        
        waitForExpectations(timeout: 5, handler: { error in
            XCTAssertNil(error, "Error")
        })
    }
    
    func testSerialization() {
        let name = randomQueueName()
        
        // Creating a queue
        var queue: SYNQueue? = SYNQueue(queueName: name, maxConcurrency: 3, maxRetries: 2, logProvider: logger, serializationProvider: serializer) { (error: NSError?, task: SYNQueueTask) -> Void in
            //
        }
        
        // Add a task to the queue
        queue!.addTaskHandler(testTaskType) {
            Thread.sleep(forTimeInterval: 2)
            $0.completed(nil)
        }
        let task = SYNQueueTask(queue: queue!, taskType: testTaskType)
        queue!.addOperation(task)
        
        // Nil out the queue to simulate app backgrounded or quit
        queue = nil
        
        // Now create a new queue (with the same name) and load serialized tasks
        let queue2 = SYNQueue(queueName: name, maxConcurrency: 3, maxRetries: 2, logProvider: logger, serializationProvider: serializer) { (error: NSError?, task: SYNQueueTask) -> Void in
            //
        }
        queue2.loadSerializedTasks()
        XCTAssert(queue2.operationCount == 1)
        
        let serializedTasks = queue2.serializationProvider?.deserializeTasks(queue2)
        serializedTasks?.forEach({ (task: SYNQueueTask) -> () in
            queue2.serializationProvider?.removeTask(task.taskID, queue: queue2)
        })
    }
    
    func testEnqueuingPerformance() {
        let queue = SYNQueue(queueName: "testQueue", maxConcurrency: 3, maxRetries: 2, logProvider: logger, serializationProvider: serializer) { (error: NSError?, task: SYNQueueTask) -> Void in
            //
        }
        
        queue.addTaskHandler(testTaskType) {
            Thread.sleep(forTimeInterval: 1)
            $0.completed(nil)
        }
        let task = SYNQueueTask(queue: queue, taskType: testTaskType)

        self.measure() {
            queue.addOperation(task)
        }
    }
}

// MARK: Helper methods
func randomQueueName() -> String {
    return UUID().uuidString
}


