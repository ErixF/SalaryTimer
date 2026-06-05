//
//  ProfileView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 6/5/26.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @AppStorage("profile.incomeType") private var incomeType: Int = 0
    @AppStorage("profile.hourlyRate") private var hourlyRateText: String = ""
    @AppStorage("profile.monthlyIncome") private var monthlyIncomeText: String = ""
    @AppStorage("profile.taxRate") private var taxRateText: String = ""
    @AppStorage("profile.hoursPerDay") private var hoursPerDayText: String = ""
    @AppStorage("profile.daysPerMonth") private var daysPerMonthText: String = ""

    @Environment(SalaryTimerStore.self) private var timerStore

    var body: some View {
        NavigationStack {
            Form {
                if timerStore.isRunning {
                    Section {
                        Label("Settings are locked while the timer is running.", systemImage: "lock.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Income") {
                    Picker("Income Type", selection: $incomeType) {
                        Text("Hourly").tag(0)
                        Text("Monthly").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if incomeType == 0 {
                        amountRow("Hourly Rate ($)", placeholder: "28", text: $hourlyRateText)
                    } else {
                        amountRow("Monthly Income ($)", placeholder: "4000", text: $monthlyIncomeText)
                        amountRow("Hours / Day", placeholder: "7", text: $hoursPerDayText)
                        amountRow("Days / Month", placeholder: "22", text: $daysPerMonthText)
                    }
                }

                Section("Tax") {
                    amountRow("Tax %", placeholder: "11", text: $taxRateText)
                }
            }
            .disabled(timerStore.isRunning)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
        }
    }

    private func amountRow(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .monospacedDigit()
        }
    }
}

#Preview {
    ProfileView()
        .environment(SalaryTimerStore())
}
