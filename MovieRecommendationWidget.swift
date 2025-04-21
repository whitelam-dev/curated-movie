import WidgetKit
import SwiftUI

// Timeline entry representing one day's recommendation
struct MovieEntry: TimelineEntry {
    let date: Date
    let title: String
    let year: Int
    let originalDirector: String
    let recommendingDirector: String
    let letterboxdURL: URL
}

// Provider for widget timeline
typealias MovieTimelineEntry = MovieEntry

struct MovieRecProvider: TimelineProvider {
    func placeholder(in context: Context) -> MovieEntry {
        MovieEntry(date: Date(), title: "Loading...", year: 0, originalDirector: "", recommendingDirector: "", letterboxdURL: URL(string: "https://letterboxd.com")!)
    }

    func getSnapshot(in context: Context, completion: @escaping (MovieEntry) -> Void) {
        let entry: MovieEntry
        if context.isPreview {
            entry = MovieEntry(
                date: Date(),
                title: "Seven Samurai",
                year: 1954,
                originalDirector: "Akira Kurosawa",
                recommendingDirector: "Quentin Tarantino",
                letterboxdURL: URL(string: "https://letterboxd.com/film/seven-samurai/")!)
        } else {
            entry = loadEntryFromStorage()
        }
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MovieEntry>) -> Void) {
        let entry = loadEntryFromStorage()
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextMidnight = Calendar.current.startOfDay(for: nextUpdate)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    private func loadEntryFromStorage() -> MovieEntry {
        let defaults = UserDefaults(suiteName: "group.com.yourapp.moviewidget")
        let title = defaults?.string(forKey: "recTitle") ?? "No Movie"
        let year = defaults?.integer(forKey: "recYear") ?? 0
        let originalDirector = defaults?.string(forKey: "recOriginalDirector") ?? ""
        let recommendingDirector = defaults?.string(forKey: "recRecommender") ?? ""
        let urlString = defaults?.string(forKey: "recLetterboxdURL") ?? "https://letterboxd.com"
        let url = URL(string: urlString) ?? URL(string: "https://letterboxd.com")!
        return MovieEntry(date: Date(), title: title, year: year, originalDirector: originalDirector, recommendingDirector: recommendingDirector, letterboxdURL: url)
    }
}

// Widget View
struct MovieWidgetEntryView: View {
    var entry: MovieRecProvider.Entry

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
            VStack(alignment: .leading, spacing: 4) {
                Text("🎬 \(entry.title)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("\(entry.year) · Dir. \(entry.originalDirector)")
                    .font(.caption)
                    .foregroundColor(.white)
                Text("Recommended by \(entry.recommendingDirector)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(8)
        }
        .widgetURL(deepLinkURL)
    }

    private var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "movierecs"
        components.host = "recommendation"
        components.queryItems = [
            URLQueryItem(name: "movieURL", value: entry.letterboxdURL.absoluteString)
        ]
        return components.url
    }
}

@main
struct MovieRecommendationWidget: Widget {
    let kind: String = "MovieRecommendationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MovieRecProvider()) { entry in
            MovieWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Daily Movie Recommendation")
        .description("Shows a daily film recommended by one of your favorite directors.")
    }
}

// Preview
struct MovieRecommendationWidget_Previews: PreviewProvider {
    static var previews: some View {
        MovieWidgetEntryView(entry: MovieEntry(
            date: Date(),
            title: "Seven Samurai",
            year: 1954,
            originalDirector: "Akira Kurosawa",
            recommendingDirector: "Quentin Tarantino",
            letterboxdURL: URL(string: "https://letterboxd.com/film/seven-samurai/")!
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
