//
//  SYNQueueTask.swift
//  SYNQueue
//

import Foundation

public typealias SYNTaskCallback = (SYNQueueTask) -> Void
public typealias SYNTaskCompleteCallback = (NSError?, SYNQueueTask) -> Void
public typealias JSONDictionary = [String: Any?]

private let MAX_RETRY_LIMIT = 3

private let keyTaskId = "taskId"
private let keyTaskType = "taskType"
private let keyTaskQos = "taskQos"
private let keyTaskData = "taskData"
private let keyTaskCreatedDate = "taskCreatedDate"
private let keyTaskRetries = "taskRetries"

/**
 *  Represents a task to be executed on a SYNQueue
 */
@objc
open class SYNQueueTask : Operation {
    static let MIN_RETRY_DELAY = 0.2
    static let MAX_RETRY_DELAY = 60.0
    
    open let queue: SYNQueue
    open let taskID: String
    open let taskType: String
    open let data: Any?
    open let created: Date
    open var retries: Int
    
    var lastError: NSError?
    var _executing: Bool = false
    var _finished: Bool = false
    
    open override var name: String? { get { return taskID } set { } }
    open override var isAsynchronous: Bool { return true }
    
    open override var isExecuting: Bool {
        get { return _executing }
        set {
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
    open override var isFinished: Bool {
        get { return _finished }
        set {
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    
    /**
     Initializes a new SYNQueueTask with the following options
     
     - parameter queue:            The queue that will execute the task
     - parameter taskID:           A unique identifier for the task, must be unique across app terminations,
     otherwise dependencies will not work correctly
     - parameter taskType:         A type that will be used to group tasks together, tasks have to be generic with respect to their type
     - parameter data:             The data that the task needs to operate on
     - parameter created:          When the task was created
     - parameter retries:          Number of times this task has been retried after failing
     - parameter qualityOfService: The quality of service
     
     - returns: A new SYNQueueTask
     */
    public init(queue: SYNQueue,
                taskType: String,
                data: Any? = nil,
                retries: Int = MAX_RETRY_LIMIT,
                qualityOfService: QualityOfService = .utility) {
        
        self.queue = queue
        self.taskType = taskType
        self.data = data
        self.retries = retries

        self.taskID = UUID().uuidString
        self.created = Date()

        super.init()
        self.qualityOfService = qualityOfService
    }
    
    // private initializer with mandatory params; to be used by the init
    private init(queue: SYNQueue,
                taskID: String,
                taskType: String,
                data: Any?,
                created: Date,
                retries: Int,
                qualityOfService: QualityOfService) {
        
        self.queue = queue
        self.taskID = taskID
        self.taskType = taskType
        self.data = data
        self.created = created
        self.retries = retries
        
        super.init()
        self.qualityOfService = qualityOfService
    }

    public init?(dictionary: JSONDictionary, queue: SYNQueue) {
        if  let taskID = dictionary[keyTaskId] as? String,
            let taskType = dictionary[keyTaskType] as? String,
            let qualityOfService = dictionary[keyTaskQos] as? Int,
            let data: Any? = dictionary[keyTaskData] as Any??,
            let createdStr = dictionary[keyTaskCreatedDate] as? String,
            let retries = dictionary[keyTaskRetries] as? Int? ?? 0 {
            
            self.queue = queue
            self.taskID = taskID
            self.taskType = taskType
            self.data = data
            self.created = Date(dateString: createdStr) ?? Date()
            self.retries = retries
            
            super.init()
            self.qualityOfService = QualityOfService(rawValue: qualityOfService) ?? .utility
            
        } else {
            return nil
        }
    }
    
    /**
     Initializes a SYNQueueTask from JSON
     
     - parameter json:    JSON from which the reconstruct the task
     - parameter queue:   The queue that the task will execute on
     
     - returns: A new SYNQueueTask
     */
    public convenience init?(json: String, queue: SYNQueue) {
        do {
            if let dict = try fromJSON(json) as? [String: Any] {
                self.init(dictionary: dict, queue: queue)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    /**
     Deconstruct the task to a dictionary, used to serialize the task
     
     - returns: A Dictionary representation of the task
     */
    open func toDictionary() -> [String: Any?] {
        var dict = [String: Any?]()
        dict[keyTaskId] = self.taskID as Any
        dict[keyTaskType] = self.taskType as Any
        dict[keyTaskQos] = self.qualityOfService.rawValue as Any
        dict[keyTaskData] = self.data
        dict[keyTaskCreatedDate] = self.created.toISOString()
        dict[keyTaskRetries] = self.retries as Any
        
        return dict
    }
    
    /**
     Deconstruct the task to a JSON string, used to serialize the task
     
     - returns: A JSON string representation of the task
     */
    open func toJSONString() -> String? {
        // Serialize this task to a dictionary
        let dict = toDictionary()
        
        // Convert the dictionary to an NSDictionary by replacing nil values
        // with NSNull
        let nsdict = NSMutableDictionary(capacity: dict.count)
        for (key, value) in dict {
            nsdict[key] = value ?? NSNull()
        }
        
        do {
            let json = try toJSON(nsdict)
            return json
        } catch {
            return nil
        }
    }
    
    /**
     Starts executing the task
     */
    open override func start() {
        super.start()
        
        isExecuting = true
        run()
    }
    
    /**
     Cancels the task
     */
    open override func cancel() {
        lastError = NSError(domain: "SYNQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task \(taskID) was cancelled"])
        
        super.cancel()
        
        queue.log(.Debug, "Canceled task \(taskID)")
        isFinished = true
    }
    
    func run() {
        if isCancelled && !isFinished { isFinished = true }
        if isFinished { return }
        
        queue.runTask(self)
    }
    
    /**
     Call this to mark the task as completed, even if it failed. If it failed, we will use exponential backoff to keep retrying
     the task until max number of retries is reached. Once this happens, we cancel the task.
     
     - parameter error: If the task failed, pass an error to indicate why
     */
    open func completed(_ error: NSError?) {
        // Check to make sure we're even executing, if not
        // just ignore the completed call
        if (!isExecuting) {
            queue.log(.Debug, "Completion called on already completed task \(taskID)")
            return
        }
        
        if let error = error {
            lastError = error
            queue.log(.Warning, "Task \(taskID) failed with error: \(error)")
            
            // Check if we've exceeded the max allowed retries
            retries += 1
            if retries >= queue.maxRetries {
                queue.log(.Error, "Max retries exceeded for task \(taskID)")
                cancel()
                return
            }
            
            // Wait a bit (exponential backoff) and retry this task
            let exp = Double(min(queue.maxRetries , retries))
            let seconds:TimeInterval = min(SYNQueueTask.MAX_RETRY_DELAY, SYNQueueTask.MIN_RETRY_DELAY * pow(2.0, exp - 1))
            
            queue.log(.Debug, "Waiting \(seconds) seconds to retry task \(taskID)")
            runInBackgroundAfter(seconds) { self.run() }
        } else {
            lastError = nil
            queue.log(.Debug, "Task \(taskID) completed")
            isFinished = true
        }
    }
}
