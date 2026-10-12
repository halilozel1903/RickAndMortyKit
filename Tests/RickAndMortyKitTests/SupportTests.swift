import Foundation
import Testing
@testable import RickAndMortyKit

@Suite("Episode codes and filters")
struct SupportTests {
    @Test func parsesEpisodeCodes() throws {
        let code = try #require(EpisodeCode("S03E07"))
        #expect(code.season == 3)
        #expect(code.episode == 7)
        #expect(code.description == "S03E07")
        #expect(code.seasonCode == "S03")

        #expect(EpisodeCode("s1e2") == EpisodeCode(season: 1, episode: 2))
        #expect(EpisodeCode(" S10E120 ")?.description == "S10E120")
    }

    @Test(arguments: ["", "S01", "E01", "S01E", "SE01", "S0xE01", "01E01", "S01E01b", "S-1E02"])
    func rejectsMalformedCodes(_ text: String) {
        #expect(EpisodeCode(text) == nil)
    }

    @Test func episodeCodesSortBySeasonThenEpisode() {
        let codes = ["S02E01", "S01E11", "S01E02", "S10E01"].compactMap { EpisodeCode($0) }
        let sorted = codes.sorted().map(\.description)
        let expected: [String] = ["S01E02", "S01E11", "S02E01", "S10E01"]
        #expect(sorted == expected)
    }

    @Test func episodeCodeIsCodableAsAString() throws {
        let code = EpisodeCode(season: 4, episode: 6)
        let data = try JSONEncoder().encode([code])
        #expect(String(decoding: data, as: UTF8.self) == #"["S04E06"]"#)
        let decoded = try JSONDecoder().decode([EpisodeCode].self, from: data)
        #expect(decoded.first == code)
    }

    @Test func blankFiltersAreNotSent() {
        let filter = CharacterFilter(name: "  ", species: "", type: nil)
        #expect(filter.isEmpty)
        #expect(CharacterFilter().queryItems.isEmpty)
        #expect(LocationFilter(dimension: "\n").isEmpty)
        #expect(EpisodeFilter().isEmpty)
    }

    @Test func filterValuesAreTrimmed() {
        let filter = LocationFilter(name: " Citadel ")
        #expect(filter.queryItems.first?.value == "Citadel")
    }

    @Test func seasonFilter() {
        #expect(EpisodeFilter(season: 4).episode == "S04")
        #expect(EpisodeFilter(season: 12).episode == "S12")
        #expect(EpisodeFilter(code: EpisodeCode(season: 2, episode: 3)).episode == "S02E03")
    }

    @Test func pageNumbersFromURLs() throws {
        let url = try #require(URL(string: "https://rickandmortyapi.com/api/character/?page=19&name=rick"))
        #expect(PageInfo.pageNumber(in: url) == 19)
        let noPage = try #require(URL(string: "https://rickandmortyapi.com/api/character/"))
        #expect(PageInfo.pageNumber(in: noPage) == nil)
    }

    @Test func airDates() throws {
        let date = try #require(APIDate.airDate(from: "September 5, 2021"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(parts.year == 2021)
        #expect(parts.month == 9)
        #expect(parts.day == 5)
        #expect(APIDate.airDate(from: "sometime") == nil)
    }
}
