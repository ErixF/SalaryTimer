//
//  SalaryTimerBundle.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/22/25.
//

import WidgetKit
import SwiftUI

@main
struct SalaryTimerBundle: WidgetBundle {
    var body: some Widget {
        SalaryTimer()
        SalaryTimerLiveActivity()
    }
}
