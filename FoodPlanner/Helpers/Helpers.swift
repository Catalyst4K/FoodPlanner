//
//  Helpers.swift
//  FoodPlanner
//
//  Created by Callum Jones on 23/04/2025.
//

import SwiftUI

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
