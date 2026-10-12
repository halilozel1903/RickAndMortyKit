import SwiftUI
import RickAndMortyKit

extension CharacterStatus {
    /// Green for alive, red for dead, gray for unknown.
    public var color: Color {
        switch self {
        case .alive: return Color(red: 0.33, green: 0.86, blue: 0.42)
        case .dead: return Color(red: 0.96, green: 0.34, blue: 0.32)
        case .unknown: return Color(red: 0.62, green: 0.64, blue: 0.68)
        }
    }

    /// An SF Symbol for the status.
    public var systemImage: String {
        switch self {
        case .alive: return "heart.fill"
        case .dead: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

/// A small dot in the status's color, with a soft glow while the character is alive.
///
/// ```swift
/// StatusDot(.alive)
/// ```
public struct StatusDot: View {
    private let status: CharacterStatus
    private let size: CGFloat

    public init(_ status: CharacterStatus, size: CGFloat = 9) {
        self.status = status
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .shadow(color: status == .alive ? status.color.opacity(0.8) : .clear, radius: size * 0.45)
            .accessibilityHidden(true)
    }
}

/// The status dot and `"Alive – Human"`, the line the API's own website shows under a name.
public struct StatusLine: View {
    private let character: RMCharacter

    public init(_ character: RMCharacter) {
        self.character = character
    }

    public var body: some View {
        HStack(spacing: 6) {
            StatusDot(character.status)
            Text(RickAndMortyFormat.statusLine(character))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RickAndMortyFormat.statusLine(character))
    }
}

/// The status dot and name on a dark capsule, for laying over an avatar.
public struct StatusBadge: View {
    private let status: CharacterStatus

    public init(_ status: CharacterStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 5) {
            StatusDot(status, size: 7)
            Text(status.displayName)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.62), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.displayName)
    }
}
