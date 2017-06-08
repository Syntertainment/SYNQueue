//
//  SettingsViewController.swift
//  SYNQueueDemo
//

import UIKit

let kAddDependencySettingKey = "settings.addDependency"
let kAutocompleteTaskSettingKey = "settings.autocompleteTask"

class SettingsViewController: UITableViewController {
    
    @IBOutlet weak var autocompleteTaskSwitch: UISwitch!
    @IBOutlet weak var dependencySwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dependencySwitch.isOn = UserDefaults.standard.bool(forKey: kAddDependencySettingKey)
        self.autocompleteTaskSwitch.isOn = UserDefaults.standard.bool(forKey: kAutocompleteTaskSettingKey)
    }
    
    @IBAction func addDependencySwitchToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: kAddDependencySettingKey)
    }
    
    @IBAction func autocompleteTaskSwitchToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: kAutocompleteTaskSettingKey)
    }
}
