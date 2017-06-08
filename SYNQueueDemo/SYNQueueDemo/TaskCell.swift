//
//  TaskCell.swift
//  SYNQueueDemo
//

import UIKit
import SYNQueue

class TaskCell : UICollectionViewCell {
    @IBOutlet weak var succeedButton: UIButton!
    @IBOutlet weak var failButton: UIButton!
    @IBOutlet weak var nameLabel: UILabel!
    
    weak var task: SYNQueueTask? = nil
    
    @IBAction func succeedTapped(_ sender: UIButton) {
        if let task = task {
            task.completed(nil)
        }
    }
    
    @IBAction func failTapped(_ sender: UIButton) {
        if let task = task {
            let err = error("User tapped Fail on task \(task.taskID)")
            task.completed(err)
        }
    }
}
