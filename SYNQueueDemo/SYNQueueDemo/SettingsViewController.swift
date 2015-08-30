//
//  SettingsViewController.swift
//  SYNQueueDemo
//
//  Created by Sidhant Gandhi on 8/25/15.
//  Copyright (c) 2015 Syntertainment. All rights reserved.
//

import UIKit

let kAddDependencySettingKey = "settings.addDependency"
let kAutocompleteTaskSettingKey = "settings.autocompleteTask"

class SettingsViewController: UITableViewController {
    
    @IBOutlet weak var autocompleteTaskSwitch: UISwitch!
    @IBOutlet weak var dependencySwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dependencySwitch.on = NSUserDefaults.standardUserDefaults().boolForKey(kAddDependencySettingKey)
        self.autocompleteTaskSwitch.on = NSUserDefaults.standardUserDefaults().boolForKey(kAutocompleteTaskSettingKey)
    }
    
    @IBAction func addDependencySwitchToggled(sender: UISwitch) {
        NSUserDefaults.standardUserDefaults().setBool(sender.on, forKey: kAddDependencySettingKey)
    }
    
    @IBAction func autocompleteTaskSwitchToggled(sender: UISwitch) {
        NSUserDefaults.standardUserDefaults().setBool(sender.on, forKey: kAutocompleteTaskSettingKey)
    }
}
