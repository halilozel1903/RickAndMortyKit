import SwiftUI
import RickAndMortyKit

/// A horizontal row of chips for the character filters the API offers by value: status and
/// gender. Tap a chip to filter, tap it again to clear it.
///
/// ```swift
/// @State private var filter = CharacterFilter()
///
/// FilterBar(status: $filter.status, gender: $filter.gender)
/// ```
public struct FilterBar: View {
    @Binding private var status: CharacterStatus?
    @Binding private var gender: CharacterGender?

    public init(status: Binding<CharacterStatus?>, gender: Binding<CharacterGender?>) {
        _status = status
        _gender = gender
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CharacterStatus.allCases, id: \.self) { value in
                    FilterChip(value.displayName, isSelected: status == value, tint: value.color) {
                        status = status == value ? nil : value
                    } leading: {
                        StatusDot(value, size: 8)
                    }
                }
                Divider()
                    .frame(height: 22)
                    .padding(.horizontal, 2)
                ForEach(CharacterGender.allCases, id: \.self) { value in
                    FilterChip(value.displayName, isSelected: gender == value) {
                        gender = gender == value ? nil : value
                    } leading: {
                        Image(systemName: FilterBar.systemImage(for: value))
                            .font(.caption)
                    }
                }
                if status != nil || gender != nil {
                    Button {
                        status = nil
                        gender = nil
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    static func systemImage(for gender: CharacterGender) -> String {
        switch gender {
        case .female: return "figure.stand.dress"
        case .male: return "figure.stand"
        case .genderless: return "circle.dotted"
        case .unknown: return "questionmark"
        }
    }
}

/// A capsule toggle with a title and a leading view, filled with `tint` when selected.
public struct FilterChip<Leading: View>: View {
    private let title: String
    private let isSelected: Bool
    private let tint: Color
    private let action: () -> Void
    private let leading: Leading

    public init(
        _ title: String,
        isSelected: Bool,
        tint: Color = Color.accentColor,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.isSelected = isSelected
        self.tint = tint
        self.action = action
        self.leading = leading()
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                leading
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(isSelected ? tint.opacity(0.28) : Color.primary.opacity(0.07))
            }
            .overlay {
                Capsule().strokeBorder(isSelected ? tint.opacity(0.9) : Color.primary.opacity(0.1))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension FilterChip where Leading == EmptyView {
    /// A chip with only a title.
    public init(_ title: String, isSelected: Bool, tint: Color = Color.accentColor, action: @escaping () -> Void) {
        self.init(title, isSelected: isSelected, tint: tint, action: action) {
            EmptyView()
        }
    }
}
