import SwiftUI
import RickAndMortyKit

/// A character's avatar, name and status.
///
/// - `.tile`: a square avatar with a status badge, the name and `"Alive – Human"` below, for
///   grids.
/// - `.row`: a round avatar beside the name, status line and last known location, for lists.
///
/// ```swift
/// LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))]) {
///     ForEach(characters) { CharacterCard(character: $0) }
/// }
/// List(characters) { CharacterCard(character: $0, style: .row) }
/// ```
public struct CharacterCard: View {
    public enum Style: Sendable {
        case tile
        case row
    }

    private let character: RMCharacter
    private let style: Style

    public init(character: RMCharacter, style: Style = .tile) {
        self.character = character
        self.style = style
    }

    public var body: some View {
        switch style {
        case .tile: tile
        case .row: row
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 0) {
            RickAndMortyImage(url: character.image, name: character.name)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    StatusBadge(character.status)
                        .padding(8)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(character.speciesDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Label(character.location.displayName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var row: some View {
        HStack(spacing: 14) {
            RickAndMortyImage(url: character.image, name: character.name)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    StatusDot(character.status, size: 12)
                        .overlay { Circle().stroke(Color.black.opacity(0.6), lineWidth: 2) }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(character.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(RickAndMortyFormat.statusLine(character))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Text(character.location.displayName)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        "\(character.name), \(RickAndMortyFormat.statusLine(character)), last seen at \(character.location.displayName)"
    }
}
