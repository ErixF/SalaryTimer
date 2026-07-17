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
            ZStack {
                ProfileBackground()
                    .ignoresSafeArea()
                
                List {
                    if timerStore.isRunning {
                        Section {
                            Label("Settings are locked while the timer is running.", systemImage: "lock.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(listRowBackground)
                        .listRowSeparator(.hidden)
                    }

                    Section {
                        VStack(spacing: 0) {
                            Picker("Income Type", selection: $incomeType) {
                                Text("Hourly").tag(0)
                                Text("Monthly").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 8)
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            if incomeType == 0 {
                                amountRow("Hourly Rate ($)", placeholder: "28", text: $hourlyRateText)
                                    .padding(.vertical, 11)
                            } else {
                                VStack(spacing: 0) {
                                    amountRow("Monthly Income ($)", placeholder: "4000", text: $monthlyIncomeText)
                                        .padding(.vertical, 11)
                                    
                                    Divider()
                                        .padding(.leading, 16)
                                    
                                    amountRow("Hours / Day", placeholder: "7", text: $hoursPerDayText)
                                        .padding(.vertical, 11)
                                    
                                    Divider()
                                        .padding(.leading, 16)
                                    
                                    amountRow("Days / Month", placeholder: "22", text: $daysPerMonthText)
                                        .padding(.vertical, 11)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        Text("Income")
//                            .colorScheme(.dark)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(listRowBackground)
                    .listRowSeparator(.hidden)

                    Section {
                        amountRow("Tax %", placeholder: "11", text: $taxRateText)
                            .padding(.vertical, 11)
                            .padding(.horizontal, 16)
                    } header: {
                        Text("Tax")
//                            .colorScheme(.dark)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(listRowBackground)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .disabled(timerStore.isRunning)
            .navigationTitle("Profile")
            .colorScheme(.dark)
            .navigationBarTitleDisplayMode(.large)
//            .toolbarColorScheme(.dark, for: .navigationBar)
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
    
    @ViewBuilder
    private var listRowBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .rect(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
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
