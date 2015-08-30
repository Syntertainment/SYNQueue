//
//  SYNQueueTask.swift
//  SYNQueue
//
//  Created by John Hurliman on 6/18/15.
//  Copyright (c) 2015 Syntertainment. All rights reserved.
//

import Foundation

public typealias SYNTaskCallback = (SYNQueueTask) -> Void
public typealias SYNTaskCoalescingCallback = ([SYNQueueTask]) -> SYNQueueTask
public typealias SYNTaskCompleteCallback = (NSError?, SYNQueueTask) -> Void
public typealias JSONDictionary = [String: AnyObject?]

/**
*  Represents a task to be executed on a SYNQueue
*/
@objc
public class SYNQueueTask : NSOperation {
    static let MIN_RETRY_DELAY = 0.2
    static let MAX_RETRY_DELAY = 60.0
    
    public let queue: SYNQueue
    public let taskID: String
    public let taskType: String
    public let data: AnyObject?
    public let created: NSDate
    public var started: NSDate?
    public var retries: Int
    
    let dependencyStrs: [String]
    var lastError: NSError?
    var _executing: Bool = false
    var _finished: Bool = false
    
    public override var name: String? { get { return taskID } set { } }
    public override var asynchronous: Bool { return true }
    
    public override var executing: Bool {
        get { return _executing }
        set {
            willChangeValueForKey("isExecuting")
            _executing = newValue
            didChangeValueForKey("isExecuting")
        }
    }
    public override var finished: Bool {
        get { return _finished }
        set {
            willChangeValueForKey("isFinished")
            _finished = newValue
            didChangeValueForKey("isFinished")
        }
    }
    
    /**
    Initializes a new SYNQueueTask with the following options
    
    :param: queue            The queue that will execute the task
    :param: taskID           A unique identifier for the task, must be unique across app terminations, 
                             otherwise dependencies will not work correctly
    :param: taskType         A type that will be used to group tasks together, tasks have to generic with respect to their type
    :param: dependencyStrs   Identifiers for tasks that are dependencies of this task
    :param: data             The data that the task needs to operate on
    :param: created          When the task was created
    :param: started          When the task started executing
    :param: retries          Number of times this task has been retried after failing
    :param: queuePriority    The priority
    :param: qualityOfService The quality of service
    
    :returns: A new SYNQueueTask
    */
    public init(queue: SYNQueue, taskID: String? = nil, taskType: String,
        dependencyStrs: [String] = [], data: AnyObject? = nil,
        created: NSDate = NSDate(), started: NSDate? = nil, retries: Int = 0,
        queuePriority: NSOperationQueuePriority = .Normal,
        qualityOfService: NSQualityOfService = .Utility)
    {
        self.queue = queue
        self.taskID = taskID ?? NSUUID().UUIDString
        self.taskType = taskType
        self.dependencyStrs = dependencyStrs
        self.data = data
        self.created = created
        self.started = started
        self.retries = retries
        
        super.init()
        
        self.queuePriority = queuePriority
        self.qualityOfService = qualityOfService
    }
    
    public convenience init(queue: SYNQueue, type: String) {
        self.init(queue: queue, taskType: type)
    }
    
    /**
    Initializes a SYNQueueTask from a dictionary
    
    :param: dictionary A dictionary that contains the data to reconstruct a task
    :param: queue      The queue that the task will execute on

    :returns: A new SYNQueueTask
    */
    public convenience init?(dictionary: JSONDictionary, queue: SYNQueue) {
        if  let taskID = dictionary["taskID"] as? String,
            let taskType = dictionary["taskType"] as? String,
            let dependencyStrs = dictionary["dependencies"] as? [String]? ?? [],
            let queuePriority = dictionary["queuePriority"] as? Int,
            let qualityOfService = dictionary["qualityOfService"] as? Int,
            let data: AnyObject? = dictionary["data"] as AnyObject??,
            let createdStr = dictionary["created"] as? String,
            let startedStr: String? = dictionary["started"] as? String ?? nil,
            let retries = dictionary["retries"] as? Int? ?? 0
        {
            let created = NSDate(dateString: createdStr) ?? NSDate()
            let started = (startedStr != nil) ? NSDate(dateString: startedStr!) : nil
            let priority = NSOperationQueuePriority(rawValue: queuePriority) ?? .Normal
            let qos = NSQualityOfService(rawValue: qualityOfService) ?? .Utility
            
            self.init(queue: queue, taskID: taskID, taskType: taskType,
                dependencyStrs: dependencyStrs, data: data, created: created,
                started: started, retries: retries, queuePriority: priority,
                qualityOfService: qos)
        } else {
            self.init(queue: queue, taskID: "", taskType: "")
            return nil
        }
    }
    
    /**
    Initializes a SYNQueueTask from JSON
    
    :param: json    JSON from which the reconstruct the task
    :param: queue   The queue that the task will execute on
    
    :returns: A new SYNQueueTask
    */
    public convenience init?(json: String, queue: SYNQueue) {
        if let dict = fromJSON(json) as? [String: AnyObject] {
            self.init(dictionary: dict, queue: queue)
        } else {
            self.init(queue: queue, taskID: "", taskType: "")
            return nil
        }
    }
    
    /**
    Setup the dependencies for the task
    
    :param: allTasks Array of SYNQueueTasks that are dependencies of this task
    */
    public func setupDependencies(allTasks: [SYNQueueTask]) {
        dependencyStrs.map {
            (taskID: String) -> Void in
            
            let found = allTasks.filter({ taskID == $0.name })
            if let task = found.first {
                self.addDependency(task)
            } else {
                let name = self.name ?? "(unknown)"
                self.queue.log(.Warning, "Discarding missing dependency \(taskID) from \(name)")
            }
        }
    }
    
    /**
    Deconstruct the task to a dictionary, used to serialize the task
    
    :returns: A Dictionary representation of the task
    */
    public func toDictionary() -> [String: AnyObject?] {
        var dict = [String: AnyObject?]()
        dict["taskID"] = self.taskID
        dict["taskType"] = self.taskType
        dict["dependencies"] = self.dependencyStrs
        dict["queuePriority"] = self.queuePriority.rawValue
        dict["qualityOfService"] = self.qualityOfService.rawValue
        dict["data"] = self.data
        dict["created"] = self.created.toISOString()
        dict["started"] = (self.started != nil) ? self.started!.toISOString() : nil
        dict["retries"] = self.retries
        
        return dict
    }
    
    /**
    Deconstruct the task to a JSON string, used to serialize the task
    
    :returns: A JSON string representation of the task
    */
    public func toJSONString() -> String? {
        // Serialize this task to a dictionary
        let dict = toDictionary()
        
        // Convert the dictionary to an NSDictionary by replacing nil values
        // with NSNull
        let nsdict = NSMutableDictionary(capacity: dict.count)
        for (key, value) in dict {
            nsdict[key] = value ?? NSNull()
        }
        
        return toJSON(nsdict)
    }
    
    /**
    Starts executing the task
    */
    public override func start() {
        super.start()
        
        executing = true
        run()
    }
    
    /**
    Cancels the task
    */
    public override func cancel() {
        lastError = NSError(domain: "SYNQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task \(taskID) was cancelled"])
        
        super.cancel()
        
        queue.log(.Debug, "Canceled task \(taskID)")
        finished = true
    }
    
    func run() {
        if cancelled && !finished { finished = true }
        if finished { return }
        
        queue.runTask(self)
    }
    
    /**
    Call this to mark the task as completed, even if it failed. If it failed, we will use exponential backoff to keep retrying
    the task until max number of retries is reached. Once this happens, we cancel the task.
    
    :param: error If the task failed, pass an error to indicate why
    */
    public func completed(error: NSError?) {
        // Check to make sure we're even executing, if not
        // just ignore the completed call
        if (!executing) {
            queue.log(.Debug, "Completion called on already completed task \(taskID)")
            return
        }
        
        if let error = error {
            lastError = error
            queue.log(.Warning, "Task \(taskID) failed with error: \(error)")
            
            // Check if we've exceeded the max allowed retries
            if ++retries >= queue.maxRetries {
                queue.log(.Error, "Max retries exceeded for task \(taskID)")
                cancel()
                return
            }
            
            // Wait a bit (exponential backoff) and retry this task
            let exp = Double(min(queue.maxRetries ?? 0, retries))
            let seconds:NSTimeInterval = min(SYNQueueTask.MAX_RETRY_DELAY, SYNQueueTask.MIN_RETRY_DELAY * pow(2.0, exp - 1))
            
            queue.log(.Debug, "Waiting \(seconds) seconds to retry task \(taskID)")
            runInBackgroundAfter(seconds) { self.run() }
        } else {
            lastError = nil
            queue.log(.Debug, "Task \(taskID) completed")
            finished = true
        }
    }
}
