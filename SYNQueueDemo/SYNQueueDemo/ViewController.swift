//
//  ViewController.swift
//  SYNQueueDemo
//

import UIKit
import SYNQueue

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    let reachability = Reachability.init()
    
    var totalTasksSeen = 0

    lazy var queue: SYNQueue = {
        return SYNQueue(queueName: "myQueue",
                        maxConcurrency: 2,
                        maxRetries: 3,
                        logProvider: ConsoleLogger(),
                        serializationProvider: UserDefaultsSerializer(),
                        completionBlock: { [weak self] in self?.taskComplete($0, $1) })
    }()
    
    // MARK: - UIViewController Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        queue.addTaskHandler("cellTask", taskHandler: taskHandler)
        queue.loadSerializedTasks()
    }

    override func viewDidLayoutSubviews() {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: collectionView.bounds.size.width, height: 50)
        }
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        collectionView.performBatchUpdates(nil, completion: nil)
    }
    
    // MARK: - SYNQueueTask Handling
    
    func taskHandler(_ task: SYNQueueTask) {
        // NOTE: Tasks are not actually handled here like usual since task
        // completion in this example is based on user interaction, unless
        // we enable the setting for task autocompletion
        
        log(.Info, "Running task \(task.taskID)")
        
        // Do something with data and call task.completed() when done
        // let data = task.data
        
        // Here, for example, we just auto complete the task
        let taskShouldAutocomplete = UserDefaults.standard.bool(forKey: kAutocompleteTaskSettingKey)
        if taskShouldAutocomplete {
            // Set task completion after 3 seconds
            runOnMainThreadAfterDelay(3, { () -> () in
                task.completed(nil)
            })
        }
        
        runOnMainThread { self.collectionView.reloadData() }
    }
    
    func taskComplete(_ error: NSError?, _ task: SYNQueueTask) {
        if let error = error {
            log(.Error, "Task \(task.taskID) failed with error: \(error)")
        } else {
            log(.Info, "Task \(task.taskID) completed successfully")
        }
        
        if queue.operationCount == 0 {
            totalTasksSeen = 0
        }
        
        updateProgress()
        
        runOnMainThread { self.collectionView.reloadData() }
    }
    
    // MARK: - UICollectionView Delegates
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection
        section: Int) -> Int {
        return queue.operationCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt
        indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "TaskCell", for: indexPath) as! TaskCell
        cell.backgroundColor = UIColor.red
        
        if let task = queue.operations[indexPath.item] as? SYNQueueTask {
            cell.task = task
            cell.nameLabel.text = "task \(task.taskID)"
            let taskShouldAutocomplete = UserDefaults.standard.bool(forKey: kAutocompleteTaskSettingKey)
            if task.isExecuting && !taskShouldAutocomplete {
                cell.backgroundColor = UIColor.blue
                cell.failButton.isEnabled = true
                cell.succeedButton.isEnabled = true
            } else {
                cell.backgroundColor = UIColor.gray
                cell.succeedButton.isEnabled = false
                cell.failButton.isEnabled = false
            }
        }
        
        return cell
    }
    
    // MARK: - IBActions
    
    @IBAction func addTapped(_ sender: UIButton) {
        
        let task1 = SYNQueueTask(queue: queue, taskType: "cellTask")
        
        if UserDefaults.standard.bool(forKey: kAddDependencySettingKey) {
            let task2 = SYNQueueTask(queue: queue, taskType: "cellTask")
            // Make the first task dependent on the second
            task1.addDependency(task2)
            queue.addOperation(task2)
        }
        
        queue.addOperation(task1)
        totalTasksSeen = max(totalTasksSeen, queue.operationCount)
        updateProgress()
        
        collectionView.reloadData()
    }
    
    @IBAction func removeTapped(_ sender: UIButton) {
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
