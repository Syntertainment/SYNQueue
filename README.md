<div align="center">
<img src="image/logo.png?raw=true"></img>
<br>
<br>
<em>A simple yet powerful queueing system for iOS (with persistence).</em>
<br>
<br>
<img title="Carthage compatible" src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat">
<img title="Build status" src="https://travis-ci.org/THREDOpenSource/SYNQueue.svg">
</div>

## Overview

`SYNQueue` is a subclass of `NSOperationQueue` so you get:

- Serial or concurrent queues
- Task priority
- Multiple queues
- Dependencies
- KVC/KVO
- Thread safety

**But it goes beyond `NSOperationQueue` and `NSOperation` to offer:**

- Task persistence (via protocol)
- Queue specific logging (via protocol)
- Retries (exponential back-off)

## Motivation
With a good queuing solution you can provide a much better user experience in areas such as:

- Web requests
- Saving/creating content (images, video, audio)
- Uploading data

## Architecture
When we started building `SYNQueue`, persistence was the most important feature for us since we hadn't seen a good generic implementation of it anywhere. With that in mind, we designed each `SYNQueueTask` (`:NSOperation`) to hold just metadata about the task rather than code itself. 

The actual code to perform the task gets passed to the queue in the form of a `taskHandler` closure. Each `SYNQueueTask` must have a `taskType` key which corresponds to a specific `taskHandler`.

## Example Code
For a thorough example see the demo project in the top level of the repository.

### Create a queue
```swift
let queue = SYNQueue(queueName: "myQueue", maxConcurrency: 2, maxRetries: 3,
            logProvider: ConsoleLogger(), serializationProvider: NSUserDefaultsSerializer(),
            completionBlock: { [weak self] in self?.taskComplete($0, $1) })
```

>The `logProvider` and `serializationProvider` must conform to the `SYNQueueLogProvider` and `SYNQueueSerializationProvider` protocols respectively. 
>
>See [NSUserDefaultsSerializer.swift](SYNQueueDemo/SYNQueueDemo/NSUserDefaultsSerializer.swift) and [ConsoleLogger.swift](SYNQueueDemo/SYNQueueDemo/ConsoleLogger.swift) for example implementations.
>
>The `completionBlock` is the block to run when a task in the queue completes (success or failure).

### Create a task
```swift
let t1 = SYNQueueTask(queue: queue, taskID: "1234", taskType: "uploadPhoto", dependencyStrs: [], data: [:])
```

>The `queue` is the queue you will add the task to. `taskID` is a unique ID for the task. `taskType` is the generic type of task to perform. Each `taskType` will have its own `taskHandler`. `data` is any data your task will need to perform its job.

### Add dependencies
```swift
let t2 = SYNQueueTask(queue: queue, taskID: "5678", taskType: "submitForm", dependencyStrs: [], data: [:])
t2.addDependency(t1)
```

### Add it to the queue
```swift
queue.addOperation(t2)
queue.addOperation(t1)
```

>Notice that even though we add task `t2` to the queue first, it will not execute until its dependency, `t1` has finished executing.`

## An important note on persistence
You may have realized that you are free to serialize tasks however you like through the `SYNQueueSerializationProvider` protocol. **The one caveat is that all tasks must be idempotent.** That is, even if called multiple times, the outcome of the task should be the same. For example: `x = 1` is idempotent, `x++` is not.

Hopefully this makes sense given that a serialized task may get interrupted before it finishes, and when we deserialize this task we will run it again. We only remove the serialized task after it has completed (success or failure).
