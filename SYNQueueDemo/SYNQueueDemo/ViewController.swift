//
//  ViewController.swift
//  SYNQueueDemo
//
//  Created by John Hurliman on 6/18/15.
//  Copyright (c) 2015 Syntertainment. All rights reserved.
//

import UIKit
import SYNQueue

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var totalTasksSeen = 0
    var nextTaskID = 1
    lazy var queue: SYNQueue = {
        return SYNQueue(queueName: "myQueue", maxConcurrency: 1, maxRetries: 3,
            logProvider: ConsoleLogger(), serializationProvider: NSUserDefaultsSerializer(),
            completionBlock: { [weak self] in self?.taskComplete($0, $1) })
    }()
    
    // MARK: - UIViewController Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        queue.addTaskHandler("cellTask", taskHandler: taskHandler)
        queue.addTaskCoalescingHandler("cellTask", taskCoalescingHandler: taskCoalescingHandler)
        queue.addTaskHandler("cellTaskCoalesced", taskHandler: coalescedTaskHandler)
        queue.loadSerializedTasks()
        
        let taskIDs = queue.operations
            .map { return $0 as? SYNQueueTask }
            .map { return $0?.taskID.toInt() ?? 0 }
        nextTaskID = (arrayMax(taskIDs) ?? 0) + 1
    }
    
    override func viewDidLayoutSubviews() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSizeMake(collectionView.bounds.size.width, 50)
        }
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        collectionView.performBatchUpdates(nil, completion: nil)
    }
    
    // MARK: - SYNQueueTask Handling
    
    func taskHandler(task: SYNQueueTask) {
        // NOTE: Tasks are not actually handled here like usual since task
        // completion in this example is based on user interaction, unless
        // we enable the setting for task autocompletion
        
        log(.Info, "Running task \(task.taskID)")
        
        // Do something with data and call task.completed() when done
        // let data = task.data
        
        // Here, for example, we just auto complete the task
        let taskShouldAutocomplete = NSUserDefaults.standardUserDefaults().boolForKey(kAutocompleteTaskSettingKey)
        if taskShouldAutocomplete {
            // Set task completion after 3 seconds
            runOnMainThreadAfterDelay(3, { () -> () in
                task.completed(nil)
            })
        }
        
        runOnMainThread { self.collectionView.reloadData() }
    }
    
    func coalescedTaskHandler(task: SYNQueueTask) {
        // NOTE: Here we would find a clever way to coalesce the task
        
        if let taskDataArray = task.data as? Array<AnyObject> {
            // Do something
        }
        
        // Here, for example, we just auto complete the task
        let taskShouldAutocomplete = NSUserDefaults.standardUserDefaults().boolForKey(kAutocompleteTaskSettingKey)
        if taskShouldAutocomplete {
            // Set task completion after 3 seconds
            runOnMainThreadAfterDelay(3, { () -> () in
                task.completed(nil)
            })
        }
        
        runOnMainThread { self.collectionView.reloadData() }
    }
    
    func taskCoalescingHandler(tasks: [SYNQueueTask]) -> SYNQueueTask {
        
        log(.Info, "Coalescing tasks" + ", ".join(tasks.map({ return $0.taskID })))
        
        var dataArray = [AnyObject]()
        for task in tasks {
            if let data: AnyObject = task.data {
                dataArray.append(data)
            }
        }
        
        let coalescedTask = SYNQueueTask(queue: queue, taskID: ", ".join(tasks.map({ return $0.taskID })), taskType: "cellTaskCoalesced", dependencyStrs: [], data: dataArray)
        
        return coalescedTask
    }
    
    func taskComplete(error: NSError?, _ task: SYNQueueTask) {
        if let error = error {
            log(.Error, "Task \(task.taskID) failed with error: \(error)")
        } else {
            log(.Info, "Task \(task.taskID) completed successfully")
        }
        
        if queue.operationCount == 0 {
            nextTaskID = 1
            totalTasksSeen = 0
        }
        
        updateProgress()
        
        runOnMainThread { self.collectionView.reloadData() }
    }
    
    // MARK: - UICollectionView Delegates
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection
        section: Int) -> Int
    {
        return queue.operationCount
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath
        indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(
            "TaskCell", forIndexPath: indexPath) as! TaskCell
        cell.backgroundColor = UIColor.redColor()
        
        if let task = queue.operations[indexPath.item] as? SYNQueueTask {
            cell.task = task
            cell.nameLabel.text = "task \(task.taskID)"
            let taskShouldAutocomplete = NSUserDefaults.standardUserDefaults().boolForKey(kAutocompleteTaskSettingKey)
            if task.executing && !taskShouldAutocomplete {
                cell.backgroundColor = UIColor.blueColor()
                cell.failButton.enabled = true
                cell.succeedButton.enabled = true
            } else {
                cell.backgroundColor = UIColor.grayColor()
                cell.succeedButton.enabled = false
                cell.failButton.enabled = false
            }
        }
        
        return cell
    }
    
    // MARK: - IBActions
    
    @IBAction func addTapped(sender: UIBarButtonItem) {
        let taskID1 = nextTaskID++
        let task1 = SYNQueueTask(queue: queue, taskID: String(taskID1),
            taskType: "cellTask", dependencyStrs: [], data: [:])
        
        let shouldAddDependency = NSUserDefaults.standardUserDefaults().boolForKey(kAddDependencySettingKey)
        if shouldAddDependency {
            let taskID2 = nextTaskID++
            let task2 = SYNQueueTask(queue: queue, taskID: String(taskID2),
                taskType: "cellTask", dependencyStrs: [], data: [:])

            // Make the first task dependent on the second
            task1.addDependency(task2)
            queue.addOperation(task2)
        }
        
        queue.addOperation(task1)
        totalTasksSeen = max(totalTasksSeen, queue.operationCount)
        updateProgress()
        
        collectionView.reloadData()
    }
    
    @IBAction func removeTapped(sender: UIBarButtonItem) {
        // Find the first task in the list
        if let task = queue.operations.first as? SYNQueueTask {
            log(.Info, "Removing task \(task.taskID)")
            
            task.cancel()
            
            collectionView.reloadData()
        }
    }
    
    // MARK: - Helpers
    
    func updateProgress() {
        let tasks = queue.tasks
        let progress = Double(totalTasksSeen - tasks.count) / Double(totalTasksSeen)
        
        runOnMainThread { self.progressView.progress = Float(progress) }
    }
}
