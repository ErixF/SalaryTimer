//
//  ContentView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 5/20/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    // MARK: – Inputs
    @State private var incomeType = 0              // 0 = hourly, 1 = monthly
    @State private var hourlyRateText: String = ""
    @State private var monthlyIncomeText: String = ""
    @State private var taxRateText: String = ""
    @State private var hoursPerDayText: String = ""
    @State private var daysPerMonthText: String = ""
    @State private var showPopup = false

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    // MARK: – Timer
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var lastStart: Date? = nil

    private var hourlyRate: Double { Double(hourlyRateText) ?? 0 }
    private var monthlyIncome: Double { Double(monthlyIncomeText) ?? 0 }
    private var taxRate: Double { Double(taxRateText) ?? 0 }
    private var hoursPerDay: Double { Double(hoursPerDayText) ?? 0 }
    private var daysPerMonth: Double { Double(daysPerMonthText) ?? 0 }

    /// Net earning per second, after tax.
    var earningPerSecond: Double {
        if incomeType == 0 {
            let netHourly = hourlyRate * (1 - taxRate/100)
            return netHourly / 3600
        } else {
            let netMonthly = monthlyIncome * (1 - taxRate/100)
            let totalSeconds = daysPerMonth * hoursPerDay * 3600
            return totalSeconds > 0 ? netMonthly / totalSeconds : 0
        }
    }

    /// Total earned so far
    var totalEarned: Double {
        elapsed * earningPerSecond
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Color(UIColor.systemGray6)
                    .ignoresSafeArea(edges: .bottom)
                    .onTapGesture {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                if geo.size.height >= geo.size.width {
                    // Portrait UI
                    VStack(spacing: 0) {
                        // Segmented picker
                        Picker("", selection: $incomeType) {
                            Text("Hourly").tag(0)
                            Text("Monthly").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical)
                        
                        // Input card
                        VStack(spacing: 0) {
                            // Rate field
                            HStack {
                                Text(incomeType == 0 ? "Hourly $" : "Monthly $")
                                Spacer()
                                if incomeType == 0 {
                                    TextField("28", text: $hourlyRateText)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                        .padding(8)
                                } else {
                                    TextField("4000", text: $monthlyIncomeText)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                        .padding(8)
                                }
                            }
                            .padding(.vertical)
                            Divider()
                            // Tax field
                            HStack {
                                Text("Tax %")
                                Spacer()
                                TextField("11", text: $taxRateText)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .padding(8)
                            }
                            .padding(.vertical)
                            
                            if incomeType == 1 {
                                Divider()
                                // Hours/day field
                                HStack {
                                    Text("Hours / Day")
                                    Spacer()
                                    TextField("7", text: $hoursPerDayText)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                        .padding(8)
                                }
                                .padding(.vertical)
                                
                                Divider()
                                
                                // Days/month field
                                HStack {
                                    Text("Days / Month")
                                    Spacer()
                                    TextField("22", text: $daysPerMonthText)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                        .padding(8)
                                }
                                .padding(.vertical)
                            }
                        }
                        .padding(.horizontal)
                        .background(colorScheme == .light
                            ? Color.white
                            : Color(UIColor.systemGray5))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
//                        .border(Color.gray.opacity(0.2), width: 1)
                        
                        // Buttons
                        HStack(spacing: 20) {
                            Button(action: startTimer) {
                                Text("Start")
                                    .frame(width: 78, height: 40)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: stopTimer) {
                                Text("Stop")
                                    .frame(width: 78, height: 40)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)

                            Button(action: resetTimer) {
                                Text("Reset")
                                    .frame(width: 78, height: 40)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        .padding(.vertical)
                        .padding(.top, 5)
                        
                        // Earnings display
                        HStack(spacing: 0) {
                            Text("≈ ")
                            Text(earningPerSecond, format: .currency(code: "USD").precision(.fractionLength(4)))
                            Text("/sec")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical)
                        
                        Text(totalEarned, format: .currency(code: "USD"))
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .monospacedDigit()
                        
                        Spacer()
                    }
                } else {
                    // Landscape: full-screen only total
                    if geo.size.width < 1000 {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            Text(totalEarned, format: .currency(code: "USD"))
                                .font(.system(size: 128, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }
                    } else {
                        ZStack {
                            Text("Go get an iPhone")
                                .font(.system(size: 72, weight: .bold, design: .default))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Touch Fish")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if verticalSizeClass == .regular {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showPopup = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .offset(y: 8)
                        }
                    }
                }
            }
            .alert("RESET APP", isPresented: $showPopup) {
                Button("OK", action: resetApp)
            }
            .onAppear {
//                startTimer()    // FOR DEBUG
            }
        }
    }

    // MARK: – Timer controls
    func startTimer() {
        guard timer == nil else { return }
        lastStart = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let start = lastStart {
                elapsed += Date().timeIntervalSince(start)
                lastStart = Date()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        lastStart = nil
    }

    func resetTimer() {
        stopTimer()
        elapsed = 0
    }

    /// Reset all inputs and timer to initial state
    func resetApp() {
        stopTimer()
        // Reset state variables
        incomeType = 0
        hourlyRateText = ""
        monthlyIncomeText = ""
        taxRateText = ""
        hoursPerDayText = ""
        daysPerMonthText = ""
        elapsed = 0
    }
}

#Preview {
    ContentView()
}
