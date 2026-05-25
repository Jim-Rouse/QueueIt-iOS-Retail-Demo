//
//  SharedPreferencesService.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

class SharedPreferencesService {
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Save Data
    func saveData(_ key: String, value: Any?) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize() // Force immediate save (optional but mirrors Android behavior)
        
        if UtilConstants.QUEUE_IT_LOGGING_ENABLED {
            if let strValue = value as? String {
                QLog("Saved to UserDefaults - Key: \(key), Value: \(strValue)")
            } else if value == nil {
                QLog("Cleared from UserDefaults - Key: \(key)")
            } else {
                QLog("Saved to UserDefaults - Key: \(key)")
            }
        }
    }
    
    // MARK: - Get Data
    func getValue(_ key: String, defaultValue: String? = nil) -> String? {
        let value = userDefaults.string(forKey: key) ?? defaultValue
        
        if UtilConstants.QUEUE_IT_LOGGING_ENABLED && value != nil {
            QLog("Retrieved from UserDefaults - Key: \(key), Value: \(value ?? "nil")")
        }
        
        return value
    }
    
    // MARK: - Remove Data
    func removeValue(_ key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
        
        if UtilConstants.QUEUE_IT_LOGGING_ENABLED {
            QLog("Removed from UserDefaults - Key: \(key)")
        }
    }
    
    // MARK: - Clear All (Optional utility)
    func clearAll() {
        let dictionary = userDefaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            userDefaults.removeObject(forKey: key)
        }
        userDefaults.synchronize()
        
        if UtilConstants.QUEUE_IT_LOGGING_ENABLED {
            QLog("Cleared all UserDefaults data")
        }
    }
}