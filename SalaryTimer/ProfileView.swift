//
//  ProfileView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 6/5/26.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @AppStorage(ProfileKeys.incomeType) private var incomeType: Int = 0
    @AppStorage(ProfileKeys.hourlyRate) private var hourlyRateText: String = ""
    @AppStorage(ProfileKeys.monthlyIncome) private var monthlyIncomeText: String = ""
    @AppStorage(ProfileKeys.taxRate) private var taxRateText: String = ""
    @AppStorage(ProfileKeys.hoursPerDay) private var hoursPerDayText: String = ""
    @AppStorage(ProfileKeys.daysPerMonth) private var daysPerMonthText: String = ""

    @Environment(SalaryTimerStore.self) private var timerStore

    @State private var showsSaved = false
    @State private var savedTask: Task<Void, Never>? = nil
    @FocusState private var focusedField: Field?

    /// Input fields, used to keep the focused one scrolled above the keyboard.
    private enum Field: Hashable {
        case hourlyRate, monthlyIncome, hoursPerDay, daysPerMonth, deductions
    }

    private var rates: RateCalculator {
        RateCalculator(
            incomeType: incomeType,
            hourlyRateText: hourlyRateText,
            monthlyIncomeText: monthlyIncomeText,
            hoursPerDayText: hoursPerDayText,
            daysPerMonthText: daysPerMonthText,
            deductionText: taxRateText
        )
    }

    /// Changes to any input trigger the "Saved" check (values auto-save via @AppStorage).
    private var editKey: [String] {
        ["\(incomeType)", hourlyRateText, monthlyIncomeText, taxRateText, hoursPerDayText, daysPerMonthText]
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    statusBanner

                    sectionLabel("Income")
                    incomeCard
                        .disabled(timerStore.isRunning)

                    previewCard
                        .padding(.top, 14)

                    sectionLabel("Deductions (optional)")
                    GroupedCard {
                        fieldRow("Deductions", placeholder: "Optional", unit: "%", text: $taxRateText, field: .deductions)
                    }
                    .disabled(timerStore.isRunning)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Leave blank if you don't know — we'll show your gross rate instead. Add one combined % for tax and any other withholdings only if you want a take-home estimate. It's an estimate either way: real deductions vary from paycheque to paycheque, and blank is a perfectly good answer.")
                        Text("Changing Deductions only affects upcoming sessions. Saved records keep the rate they were recorded with.")
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { _, field in
                guard let field else { return }
                // Wait for the keyboard to settle, then bring the field above it.
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            }
            .background {
                ScreenBackground()
                    .ignoresSafeArea()
            }
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
            .onChange(of: editKey) {
                flashSaved()
            }
        }
        // Outside the NavigationStack so it sits just below the Dynamic Island,
        // matching the Meter's "Saved to Records" toast, not below the large title.
        .overlay(alignment: .top) {
            if showsSaved {
                ToastView(message: "Saved")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Banner

    /// Running: inputs are locked. Paused: edits are allowed and apply from the next Resume.
    @ViewBuilder
    private var statusBanner: some View {
        switch timerStore.state {
        case .running:
            banner(
                "Locked while the meter is running. Pause or Archive & Reset to make changes.",
                systemImage: "lock.fill",
                tint: .orange
            )
        case .paused:
            banner(
                "Meter is paused. Changes apply when you resume.",
                systemImage: "pause.circle.fill",
                tint: .green
            )
        case .idle:
            EmptyView()
        }
    }

    private func banner(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            }
            .padding(.top, 4)
    }

    // MARK: - Income

    private var incomeCard: some View {
        GroupedCard {
            Picker("Income Type", selection: $incomeType) {
                Text("Hourly").tag(0)
                Text("Monthly").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 6)

            // Each mode keeps its own stored values; switching never clears the other.
            if incomeType == 0 {
                fieldRow("Hourly Rate", placeholder: "28", unit: "$/hr", text: $hourlyRateText, field: .hourlyRate)
            } else {
                fieldRow("Monthly Income", placeholder: "4000", unit: "$/mo", text: $monthlyIncomeText, field: .monthlyIncome)
                Divider()
                fieldRow("Hours / Day", placeholder: "7", unit: "hrs", text: $hoursPerDayText, field: .hoursPerDay)
                Divider()
                fieldRow("Days / Month", placeholder: "22", unit: "days", text: $daysPerMonthText, field: .daysPerMonth)
            }
        }
    }

    /// Label on the left, a boxed editable value with its unit on the right.
    private func fieldRow(_ title: String, placeholder: String, unit: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body.weight(.medium))

            Spacer(minLength: 8)

            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: 100)
                .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.primary.opacity(0.12), lineWidth: 1)
                }

            Text(unit)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
        .padding(.vertical, 6)
        .id(field)
    }

    // MARK: - Preview

    /// Live breakdown of the rate, one plain row per step of the math.
    private var previewCard: some View {
        let rates = rates
        return VStack(alignment: .leading, spacing: 0) {
            Text(rates.hasDeductions ? "Your take-home rate" : "Your gross rate")
                .font(.system(size: 11.5, weight: .bold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(.green)

            Text("\(money(rates.netHourly))/hr")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .padding(.top, 5)

            VStack(spacing: 0) {
                if rates.incomeType == 0 {
                    previewRow("Hourly rate you entered", "\(money(rates.grossHourly))/hr")
                } else {
                    previewRow("Monthly income you entered", wholeMoney(rates.monthlyIncome))
                    previewRow(
                        "Hours in a month",
                        "\(number(rates.daysPerMonth)) days × \(number(rates.hoursPerDay)) hrs = \(number(rates.monthlyHours)) hrs"
                    )
                    previewRow(
                        "Gross hourly rate",
                        "\(wholeMoney(rates.monthlyIncome)) ÷ \(number(rates.monthlyHours)) hrs = \(money(rates.grossHourly))/hr"
                    )
                }

                if rates.hasDeductions {
                    previewRow(
                        "Less deductions (\(number(rates.deduction))%)",
                        "−\(money(rates.grossHourly - rates.netHourly))/hr"
                    )
                }

                previewRow(
                    rates.hasDeductions ? "Take-home rate" : "Gross rate",
                    "\(money(rates.netHourly))/hr",
                    isResult: true
                )
                previewRow("Per second", "$\(rates.netPerSecond.formatted(.number.precision(.fractionLength(4))))/sec")

                if rates.incomeType == 0 {
                    previewRow("Per 8-hour day", money(rates.netHourly * 8))
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [.green.opacity(0.22), .green.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.green.opacity(0.35), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: rates.hasDeductions)
    }

    private func previewRow(_ label: String, _ value: String, isResult: Bool = false) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(label)
                    .foregroundStyle(isResult ? .primary : .secondary)
                Spacer(minLength: 8)
                Text(value)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            .font(isResult ? .subheadline.weight(.heavy) : .footnote.weight(.semibold))
            .padding(.vertical, 8)
        }
    }

    // MARK: - Saved

    private func flashSaved() {
        savedTask?.cancel()
        withAnimation(.spring(duration: 0.35)) { showsSaved = true }
        savedTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { showsSaved = false }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
    }

    private func money(_ value: Double) -> String {
        "$\(value.formatted(.number.precision(.fractionLength(2))))"
    }

    /// `$4,000` — no forced decimals for whole amounts.
    private func wholeMoney(_ value: Double) -> String {
        "$\(value.formatted(.number.precision(.fractionLength(0...2))))"
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

#Preview {
    ProfileView()
        .environment(SalaryTimerStore(restoresSession: false))
}
