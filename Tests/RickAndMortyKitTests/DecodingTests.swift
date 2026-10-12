import Foundation
import Testing
@testable import RickAndMortyKit

@Suite("Decoding the API's JSON")
struct DecodingTests {
    @Test func character() throws {
        let rick = try Fixture.decode(RMCharacter.self, from: "character")

        #expect(rick.id == 1)
        #expect(rick.name == "Rick Sanchez")
        #expect(rick.status == .alive)
        #expect(rick.species == "Human")
        #expect(rick.type.isEmpty)
        #expect(rick.gender == .male)
        #expect(rick.origin.name == "Earth (C-137)")
        #expect(rick.origin.id == 1)
        #expect(rick.location.name == "Citadel of Ricks")
        #expect(rick.location.id == 3)
        #expect(rick.image?.absoluteString == "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
        #expect(rick.url?.absoluteString == "https://rickandmortyapi.com/api/character/1")
        #expect(rick.episodeURLs.count == 51)
        #expect(rick.episodeIDs.first == 1)
        #expect(rick.episodeIDs.last == 51)
        #expect(rick.speciesDescription == "Human")
    }

    @Test func createdTimestampKeepsMilliseconds() throws {
        let rick = try Fixture.decode(RMCharacter.self, from: "character")
        let created = try #require(rick.created)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: created)
        #expect(parts.year == 2017)
        #expect(parts.month == 11)
        #expect(parts.day == 4)
        #expect(parts.hour == 18)
        #expect(parts.minute == 48)
        #expect(parts.second == 46)
        let milliseconds = Int((created.timeIntervalSince1970 * 1000).rounded()) % 1000
        #expect(milliseconds == 250)
        #expect(APIDate.string(fromTimestamp: created) == "2017-11-04T18:48:46.250Z")
    }

    @Test func unknownOriginHasNoURL() throws {
        let morty = try Fixture.decode(RMCharacter.self, from: "character-unknown-origin")

        #expect(morty.name == "Morty Smith")
        #expect(morty.origin.name == "unknown")
        #expect(morty.origin.url == nil)
        #expect(morty.origin.id == nil)
        #expect(morty.origin.isUnknown)
        #expect(morty.origin.displayName == "Unknown")
        #expect(morty.location.isUnknown == false)
    }

    @Test func charactersPage() throws {
        let page = try Fixture.decode(Page<RMCharacter>.self, from: "characters-page-1")

        #expect(page.info.count == 826)
        #expect(page.info.pages == 42)
        #expect(page.info.next?.absoluteString == "https://rickandmortyapi.com/api/character/?page=2")
        #expect(page.info.prev == nil)
        #expect(page.info.nextPage == 2)
        #expect(page.info.previousPage == nil)
        #expect(page.number == 1)
        #expect(page.hasNextPage)
        #expect(page.results.count == 20)

        let statuses = Set(page.results.map(\.status))
        let expectedStatuses: Set<CharacterStatus> = [.alive, .dead, .unknown]
        #expect(statuses == expectedStatuses)
        let typed = page.results.first(where: { $0.id == 7 })
        #expect(typed?.type == "Genetic experiment")
        #expect(typed?.speciesDescription == "Human · Genetic experiment")
        let genderless = page.results.first(where: { $0.id == 13 })
        #expect(genderless?.gender == .unknown)
    }

    @Test func middlePageNumber() throws {
        let page = try Fixture.decode(Page<RMEpisode>.self, from: "episodes-page-2")

        #expect(page.info.previousPage == 1)
        #expect(page.info.nextPage == 3)
        #expect(page.number == 2)
    }

    @Test func lastPage() throws {
        let page = try Fixture.decode(Page<RMEpisode>.self, from: "episodes-page-3")

        #expect(page.info.next == nil)
        #expect(page.number == 3)
        #expect(page.hasNextPage == false)
        #expect(page.results.count == 11)
        #expect(page.results.last?.name == "Rickmurai Jack")
    }

    @Test func location() throws {
        let earth = try Fixture.decode(RMLocation.self, from: "location")

        #expect(earth.id == 1)
        #expect(earth.name == "Earth (C-137)")
        #expect(earth.type == "Planet")
        #expect(earth.dimension == "Dimension C-137")
        #expect(earth.knownDimension == "Dimension C-137")
        #expect(earth.residentURLs.count == earth.residentIDs.count)
        #expect(earth.residentIDs.isEmpty == false)
        #expect(earth.reference.id == 1)
    }

    @Test func unknownDimension() throws {
        let locations = try Fixture.decode([RMLocation].self, from: "locations-multiple")
        let citadel = try #require(locations.last)

        #expect(citadel.name == "Citadel of Ricks")
        #expect(citadel.dimension == "unknown")
        #expect(citadel.knownDimension == nil)
    }

    @Test func episode() throws {
        let pilot = try Fixture.decode(RMEpisode.self, from: "episode")

        #expect(pilot.id == 1)
        #expect(pilot.name == "Pilot")
        #expect(pilot.airDate == "December 2, 2013")
        #expect(pilot.codeString == "S01E01")
        #expect(pilot.code == EpisodeCode(season: 1, episode: 1))
        #expect(pilot.season == 1)
        #expect(pilot.number == 1)
        let firstTwo: [Int] = [1, 2]
        #expect(Array(pilot.characterIDs.prefix(2)) == firstTwo)
    }

    @Test func airDate() throws {
        let pilot = try Fixture.decode(RMEpisode.self, from: "episode")
        let aired = try #require(pilot.airDateValue)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day], from: aired)
        #expect(parts.year == 2013)
        #expect(parts.month == 12)
        #expect(parts.day == 2)
    }

    @Test func roundTripKeepsTheAPIShape() throws {
        let morty = try Fixture.decode(RMCharacter.self, from: "character-unknown-origin")
        let encoded = try JSONEncoder().encode(morty)
        let decoded = try JSONDecoder().decode(RMCharacter.self, from: encoded)
        #expect(decoded.id == morty.id)
        #expect(decoded.origin == morty.origin)
        #expect(decoded.location == morty.location)
        #expect(decoded.episodeURLs == morty.episodeURLs)
        let createdBefore = try #require(morty.created)
        let createdAfter = try #require(decoded.created)
        #expect(abs(createdAfter.timeIntervalSince(createdBefore)) < 0.002)

        let json = try JSONSerialization.jsonObject(with: encoded)
        let object = try #require(json as? [String: Any])
        let origin = try #require(object["origin"] as? [String: Any])
        #expect(origin["url"] as? String == "")
        #expect(object["status"] as? String == "Alive")
        #expect(object["episode"] is [String])
    }

    @Test func statusAndGenderReadAnyCase() throws {
        let json = Data(#"{"id": 99, "name": "Test", "status": "ALIVE", "gender": "genderless", "origin": {"name": "unknown", "url": ""}}"#.utf8)
        let character = try JSONDecoder().decode(RMCharacter.self, from: json)

        #expect(character.status == .alive)
        #expect(character.gender == .genderless)
        #expect(character.location == .unknown)
        #expect(character.image == nil)
        #expect(character.episodeURLs.isEmpty)
        #expect(character.created == nil)
    }

    @Test func unexpectedStatusIsUnknown() {
        #expect(CharacterStatus(apiValue: "Schrödinger") == .unknown)
        #expect(CharacterGender(apiValue: "") == .unknown)
        #expect(CharacterStatus.dead.queryValue == "dead")
        #expect(CharacterGender.unknown.queryValue == "unknown")
        #expect(CharacterStatus.unknown.displayName == "Unknown")
    }
}
