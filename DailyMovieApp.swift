import SwiftUI
import WidgetKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

// Data models
struct Movie: Identifiable, Codable {
    let id: UUID = UUID()
    let title: String
    let year: Int
    let originalDirector: String
    let recommendingDirector: String
    let letterboxdURL: String
}

struct Director: Identifiable, Codable {
    let id: String
    let name: String
    let recommendedMovies: [Movie]
}

// ViewModel
class AppViewModel: ObservableObject {
    @Published var directors: [Director] = []
    @Published var selectedDirectorIDs: Set<String> = []
    @Published var todayRecommendation: Movie? = nil
    @Published var onboardingCompleted: Bool = false

    private var userID: String = ""
    private let db = Firestore.firestore()

    init() {
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { [weak self] result, error in
                if let user = result?.user {
                    self?.userID = user.uid
                    self?.loadDirectorsList()
                }
            }
        } else {
            userID = Auth.auth().currentUser?.uid ?? ""
            loadDirectorsList()
        }
    }

    func loadDirectorsList() {
        db.collection("directors").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            if let docs = snapshot?.documents {
                self.directors = docs.compactMap { doc in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let moviesData = data["recommendedMovies"] as? [[String: Any]] else { return nil }
                    let movies: [Movie] = moviesData.compactMap { m in
                        guard let title = m["title"] as? String,
                              let year = m["year"] as? Int,
                              let origDir = m["director"] as? String,
                              let url = m["letterboxdURL"] as? String else { return nil }
                        return Movie(title: title, year: year, originalDirector: origDir, recommendingDirector: name, letterboxdURL: url)
                    }
                    return Director(id: doc.documentID, name: name, recommendedMovies: movies)
                }
            } else {
                print("Error loading directors: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }

    func toggleDirectorSelection(_ director: Director) {
        if selectedDirectorIDs.contains(director.id) {
            selectedDirectorIDs.remove(director.id)
        } else if selectedDirectorIDs.count < 5 {
            selectedDirectorIDs.insert(director.id)
        }
    }

    func completeOnboarding() {
        guard selectedDirectorIDs.count == 5 else { return }
        onboardingCompleted = true
        let userDoc = db.collection("users").document(userID)
        userDoc.setData(["selectedDirectors": Array(selectedDirectorIDs)], merge: true)

        assignTodayRecommendation()
        scheduleDailyNotification()
    }

    func assignTodayRecommendation() {
        let chosen = Array(selectedDirectorIDs)
        guard let randomDirID = chosen.randomElement(),
              let director = directors.first(where: { $0.id == randomDirID }),
              let movie = director.recommendedMovies.randomElement() else { return }
        todayRecommendation = movie
        saveTodayRecToStorage(movie)
    }

    private func saveTodayRecToStorage(_ movie: Movie) {
        let defaults = UserDefaults(suiteName: "group.com.yourapp.moviewidget")
        defaults?.set(movie.title, forKey: "recTitle")
        defaults?.set(movie.year, forKey: "recYear")
        defaults?.set(movie.originalDirector, forKey: "recOriginalDirector")
        defaults?.set(movie.recommendingDirector, forKey: "recRecommender")
        defaults?.set(movie.letterboxdURL, forKey: "recLetterboxdURL")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func scheduleDailyNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                if let movie = self.todayRecommendation {
                    content.title = "🎬 \(movie.recommendingDirector) recommends \(movie.title)"
                    content.body = "\(movie.title) (\(movie.year)), directed by \(movie.originalDirector)."
                } else {
                    content.title = "🎬 Daily Movie Recommendation"
                    content.body = "Check out today's director-picked movie!"
                }
                content.sound = .default

                var comps = DateComponents()
                comps.hour = 0
                comps.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let req = UNNotificationRequest(identifier: "DailyMovieRec", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req) { err in
                    if let err = err { print("Unable to schedule notification: \(err)") }
                }
            } else {
                print("Notification permission not granted.")
            }
        }
    }
}

// App
@main
struct DailyMovieApp: App {
    @StateObject private var viewModel = AppViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    if url.scheme == "movierecs",
                       let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let item = comps.queryItems?.first(where: { $0.name == "movieURL" }),
                       let str = item?.value,
                       let movieURL = URL(string: str) {
                        UIApplication.shared.open(movieURL)
                    }
                }
        }
    }
}

// ContentView
struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        Group {
            if !viewModel.onboardingCompleted {
                OnboardingView()
            } else {
                RecommendationView()
            }
        }
    }
}

// Onboarding
struct OnboardingView: View {
    @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        NavigationView {
            List {
                Text("Select 5 Favorite Directors").font(.headline)
                ForEach(viewModel.directors) { director in
                    HStack {
                        Text(director.name)
                        Spacer()
                        if viewModel.selectedDirectorIDs.contains(director.id) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                        } else if viewModel.selectedDirectorIDs.count >= 5 {
                            Image(systemName: "circle").foregroundColor(.gray)
                        } else {
                            Image(systemName: "circle").foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.toggleDirectorSelection(director) }
                }
            }
            .navigationBarTitle("Choose Directors", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { viewModel.completeOnboarding() }
                .disabled(viewModel.selectedDirectorIDs.count != 5))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Recommendation
struct RecommendationView: View {
    @EnvironmentObject var viewModel: AppViewModel
    var body: some View {
        if let movie = viewModel.todayRecommendation {
            VStack(spacing: 16) {
                Text("Today's Recommendation").font(.title2).padding(.top)
                Text("\"\(movie.title)\" (\(movie.year))").font(.title).bold().multilineTextAlignment(.center)
                Text("Directed by \(movie.originalDirector)").foregroundColor(.secondary)
                Text("Recommended by \(movie.recommendingDirector)").foregroundColor(.secondary)
                Button(action: {
                    if let url = URL(string: movie.letterboxdURL) { UIApplication.shared.open(url) }
                }) {
                    Label("View on Letterboxd", systemImage: "film")
                } .padding(.top, 10)
            }.padding()
        } else {
            Text("Fetching today's movie...") .onAppear { viewModel.assignTodayRecommendation() }
        }
    }
}

// Preview
struct RecommendationView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = AppViewModel()
        vm.onboardingCompleted = true
        vm.todayRecommendation = Movie(title: "Seven Samurai", year: 1954, originalDirector: "Akira Kurosawa", recommendingDirector: "Quentin Tarantino", letterboxdURL: "https://letterboxd.com/film/seven-samurai/")
        return RecommendationView().environmentObject(vm).previewLayout(.sizeThatFits)
    }
}
