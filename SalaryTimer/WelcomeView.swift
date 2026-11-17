//
//  WelcomeView.swift
//  SalaryTimer
//
//  Created by Eric Feng on 11/17/26.
//

import SwiftUI

/// First-launch sheet: what the app does in three lines, then a hand-off to Income setup.
struct WelcomeView: View {
    let onSetUpIncome: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue.gradient)
                        .accessibilityHidden(true)

                    Text("Touch Fish")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))

                    Text("See what you earn, second by second.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 22) {
                    featureRow(
                        symbol: "dollarsign.circle.fill",
                        color: .green,
                        title: "Set your income",
                        text: "Hourly or monthly. Touch Fish turns it into a per-second rate."
                    )
                    featureRow(
                        symbol: "play.circle.fill",
                        color: .blue,
                        title: "Start when you clock in",
                        text: "Pause for breaks. Archive & Reset saves the session to Records."
                    )
                    featureRow(
                        symbol: "timer",
                        color: .orange,
                        title: "Follow along anywhere",
                        text: "A Live Activity keeps the timer and goal on your Lock Screen and in the Dynamic Island."
                    )
                }

                Text("Everything stays on your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 12)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Buttons stay pinned while the content scrolls at large text sizes.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Button {
                    onSetUpIncome()
                } label: {
                    Text("Set Up Income")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .controlSize(.large)

                Button("Not Now") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func featureRow(symbol: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            WelcomeView(onSetUpIncome: {})
        }
}
