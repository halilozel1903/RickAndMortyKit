import SwiftUI
import RickAndMortyKit

/// A location's name, type, dimension and number of residents, with a symbol for its type.
///
/// ```swift
/// List(locations) { LocationCard(location: $0) }
/// ```
public struct LocationCard: View {
    private let location: RMLocation

    public init(location: RMLocation) {
        self.location = location
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: LocationCard.systemImage(for: location.type))
                .font(.title2)
                .foregroundStyle(LocationCard.tint(for: location.type))
                .frame(width: 52, height: 52)
                .background {
                    Circle().fill(LocationCard.tint(for: location.type).opacity(0.18))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(RickAndMortyFormat.locationLine(location))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Label(RickAndMortyFormat.count(location.residentURLs.count, "resident"), systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(location.name), \(RickAndMortyFormat.locationLine(location)), \(RickAndMortyFormat.count(location.residentURLs.count, "resident"))")
    }

    /// An SF Symbol for a location type: a globe for planets, a moon for space stations…
    public static func systemImage(for type: String) -> String {
        switch type.lowercased() {
        case "planet": return "globe.americas.fill"
        case "space station", "spacecraft": return "moon.stars.fill"
        case "microverse", "miniverse", "teenyverse": return "atom"
        case "tv": return "tv.fill"
        case "resort", "spa": return "beach.umbrella.fill"
        case "dream": return "cloud.moon.fill"
        case "dimension": return "circle.hexagongrid.fill"
        case "cluster": return "sparkles"
        case "fantasy town", "city", "town": return "building.2.fill"
        default: return "mappin.and.ellipse"
        }
    }

    /// A color for a location type.
    public static func tint(for type: String) -> Color {
        switch type.lowercased() {
        case "planet": return Color(red: 0.30, green: 0.74, blue: 0.95)
        case "space station", "spacecraft": return Color(red: 0.75, green: 0.45, blue: 0.98)
        case "microverse", "miniverse", "teenyverse": return Color(red: 0.33, green: 0.86, blue: 0.42)
        case "dream": return Color(red: 0.98, green: 0.62, blue: 0.80)
        default: return Color(red: 0.98, green: 0.70, blue: 0.30)
        }
    }
}
