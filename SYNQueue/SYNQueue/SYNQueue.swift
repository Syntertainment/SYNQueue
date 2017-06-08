//
//  SYNQueue.swift
//  SYNQueue
//

import Foundation

/**
 Log level for use in the SYNQueueLogProvider `log()` call
 
 - Trace:   "Trace"
 - Debug:   "Debug"
 - Info:    "Info"
 - Warning: "Warning"
 - Error:   "Error"
 */
@objc
public enum LogLevel: Int {
    case Trace   = 0
    case Debug   = 1
    case Info    = 2
    case Warning = 3
    case Error   = 4
    
    public func toString() -> String {
        switch (self) {
        case .Trace:   return "Trace"
        case .Debug:   return "Debug"
        case .Info:    return "Info"
        case .Warning: return "Warning"
        case .Error:   return "Error"
        }
    }
}

/**
 *  Conform to this protocol to provide logging to SYNQueue
 */
@objc
public protocol SYNQueueLogProvider {
    func log(_ level: LogLevel, _ msg: String)
}

/**
 *  Conform to this protocol to provide serialization (persistence) to SYNQueue
 */
@objc
public protocol SYNQueueSerializationProvider {
    func serializeTask(_ task: SYNQueueTask, queueName: String)
    func deserializeTasks(_ queue: SYNQueue) -> [SYNQueueTask]
    func removeTask(_ taskID: String, queue: SYNQueue)
}

/**
 *  SYNQueue is a generic queue with customizable serialization, logging, task handling, retries, and concurrency behavior
 */
@objc
open class SYNQueue : OperationQueue {
    
    /// The maximum number of times a task will be retried if it fails
    open let maxRetries: Int
    
    let serializationProvider: SYNQueueSerializationProvider?
    let logProvider: SYNQueueLogProvider?
    var taskMap = [String: SYNQueueTask]()
    var taskHandlers = [String: SYNTaskCallback]()
    let completionBlock: SYNTaskCompleteCallback?
    
    open var tasks: [SYNQueueTask] {
        let array = operations
        
        var output = [SYNQueueTask]()
        output.reserveCapacity(array.count)
        
        for obj in array {
            if let cast = obj as? SYNQueueTask { output.append(cast) }
        }
        
        return output
    }
    
    /**
     Initializes a SYNQueue with the provided options
     
     - parameter queueName:             The name of the queue
     - parameter maxConcurrency:        The maximum number of tasks to run in parallel
     - parameter maxRetries:            The maximum times a task will be retried if it fails
     - parameter logProvider:           An optional logger, nothing will be logged if this is nil
     - parameter serializationProvider: An optional serializer, there will be no serialzation (persistence) if nil
     - parameter completionBlock:       The closure to call when a task finishes
     
     - returns: A new SYNQueue
     */
    public required init(queueName: String,
                         maxConcurrency: Int = 1,
                         maxRetries: Int = 5,
                         logProvider: SYNQueueLogProvider? = nil,
                         serializationProvider: SYNQueueSerializationProvider? = nil,
                         completionBlock: SYNTaskCompleteCallback? = nil) {
        
        self.maxRetries = maxRetries
        self.logProvider = logProvider
        self.serializationProvider = serializationProvider
        self.completionBlock = completionBlock
        
        super.init()
        
        self.name = queueName
        self.maxConcurrentOperationCount = maxConcurrency
    }
    
    /**
     Add a handler for a task type
     
     - parameter taskType:    The task type for the handler
     - parameter taskHandler: The handler for this particular task type, must be generic for the task type
     */
    open func addTaskHandler(_ taskType: String, taskHandler: @escaping SYNTaskCallback) {
        taskHandlers[taskType] = taskHandler
    }
    
    /**
     Deserializes tasks that were serialized (persisted)
     */
    open func loadSerializedTasks() {
        self.pause()
        if let sp = serializationProvider {
            let tasks = sp.deserializeTasks(self)
            for task in tasks {
                addDeserializedTask(task)
            }
        }
        self.start()
    }
    
    open func getTask(_ taskID: String) -> SYNQueueTask? {
        return taskMap[taskID]
    }
    
    /**
     Adds a SYNQueueTask to the queue and serializes it
     
     - parameter op: A SYNQueueTask to execute on the queue
     */
    override open func addOperation(_ op: Operation) {
        if let task = op as? SYNQueueTask {
            if taskMap[task.taskID] != nil {
                log(.Warning, "Attempted to add duplicate task \(task.taskID)")
                return
            }
            taskMap[task.taskID] = task
            
            // Serialize this operation
            if let sp = serializationProvider, let queueName = task.queue.name {
                sp.serializeTask(task, queueName: queueName)
            }
        }
        
        op.completionBlock = { self.taskComplete(op) }
        super.addOperation(op)
    }
    
    open func start() {
        self.isSuspended = false
    }
    
    open func pause() {
        self.isSuspended = true
    }
    
    func addDeserializedTask(_ task: SYNQueueTask) {
        if taskMap[task.taskID] != nil {
            log(.Warning, "Attempted to add duplicate deserialized task \(task.taskID)")
            return
        }
        
        task.completionBlock = { self.taskComplete(task) }
        super.addOperation(task)
    }
    
    func runTask(_ task: SYNQueueTask) {
        if let handler = taskHandlers[task.taskType] {
            handler(task)
        } else {
            log(.Warning, "No handler registered for task \(task.taskID)")
            task.cancel()
        }
    }
    
    func taskComplete(_ op: Operation) {
        if let task = op as? SYNQueueTask {
            taskMap.removeValue(forKey: task.taskID)

            if let handler = completionBlock {
                handler(task.lastError, task)
            }
            
            // Remove this operation from serialization
            if let sp = serializationProvider {
                sp.removeTask(task.taskID, queue: task.queue)
            }
        }
    }
    
    func log(_ level: LogLevel, _ msg: String) {
        logProvider?.log(level, msg)
    }
}
