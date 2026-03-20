// Features/Dashboard/Components/GoalPickerSheet.swift
import SwiftUI

enum GoalType: String, CaseIterable, Identifiable {
    case subscribers = "Subscribers"
    case watchHours  = "Watch hours"
    case views       = "Total views"
    case videos      = "Videos uploaded"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .subscribers: return "person.2.fill"
        case .watchHours:  return "clock.fill"
        case .views:       return "eye.fill"
        case .videos:      return "play.rectangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .subscribers: return .green
        case .watchHours:  return .cyan
        case .views:       return Color(red: 0.49, green: 0.44, blue: 1.0)
        case .videos:      return .orange
        }
    }

    var presets: [Int] {
        switch self {
        case .subscribers: return [1_000, 5_000, 10_000, 25_000, 50_000, 100_000]
        case .watchHours:  return [500, 1_000, 4_000, 10_000, 50_000]
        case .views:       return [10_000, 50_000, 100_000, 500_000, 1_000_000]
        case .videos:      return [10, 25, 50, 100, 200, 365]
        }
    }

    var unit: String {
        switch self {
        case .subscribers: return ""
        case .watchHours:  return "h"
        case .views:       return ""
        case .videos:      return " videos"
        }
    }
}

struct GoalPickerSheet: View {
    @Binding var isPresented: Bool
    let onSave: (GoalType, Int) -> Void

    @State private var selectedType: GoalType = .subscribers
    @State private var selectedPreset: Int?    = nil
    @State private var customValueText: String = ""
    @State private var useCustom               = false

    private var finalTarget: Int? {
        if useCustom { return Int(customValueText) }
        return selectedPreset
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.14)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header
                HStack {
                    Text("Set a goal")
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 8)

                // MARK: - Goal type selector
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("What are you tracking?")

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(GoalType.allCases) { type in
                            Button {
                                selectedType       = type
                                selectedPreset     = nil
                                customValueText    = ""
                                useCustom          = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(
                                            selectedType == type
                                                ? type.color
                                                : .white.opacity(0.3)
                                        )
                                    Text(type.rawValue)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(
                                            selectedType == type
                                                ? .white
                                                : .white.opacity(0.4)
                                        )
                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    selectedType == type
                                        ? type.color.opacity(0.12)
                                        : Color.white.opacity(0.04)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedType == type
                                                ? type.color.opacity(0.4)
                                                : Color.white.opacity(0.07),
                                            lineWidth: 0.5
                                        )
                                )
                            }
                        }
                    }
                }

                // MARK: - Target selector
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Choose a target")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedType.presets, id: \.self) { preset in
                                Button {
                                    selectedPreset  = preset
                                    useCustom       = false
                                    customValueText = ""
                                } label: {
                                    Text(formatNumber(preset) + selectedType.unit)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(
                                            selectedPreset == preset && !useCustom
                                                ? .white
                                                : .white.opacity(0.45)
                                        )
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedPreset == preset && !useCustom
                                                ? selectedType.color
                                                : Color.white.opacity(0.06)
                                        )
                                        .cornerRadius(20)
                                }
                            }

                            // Custom
                            Button {
                                useCustom      = true
                                selectedPreset = nil
                            } label: {
                                Text("Custom")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(
                                        useCustom ? .white : .white.opacity(0.45)
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        useCustom
                                            ? selectedType.color
                                            : Color.white.opacity(0.06)
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }

                    // Custom number input
                    if useCustom {
                        HStack {
                            TextField("", text: $customValueText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .placeholder(when: customValueText.isEmpty) {
                                    Text("Enter target number")
                                        .foregroundColor(.white.opacity(0.25))
                                        .font(.system(size: 15))
                                }
                            Spacer()
                            if !customValueText.isEmpty {
                                Text(selectedType.unit)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedType.color.opacity(0.4), lineWidth: 0.5)
                        )
                    }
                }

                Spacer()

                // MARK: - Save button
                Button {
                    if let target = finalTarget, target > 0 {
                        onSave(selectedType, target)
                        isPresented = false
                    }
                } label: {
                    Text("Set goal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            finalTarget != nil
                                ? selectedType.color
                                : Color.white.opacity(0.1)
                        )
                        .cornerRadius(16)
                }
                .disabled(finalTarget == nil)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.4))
            .kerning(0.8)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.0fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
