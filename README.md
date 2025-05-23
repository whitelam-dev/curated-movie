# Daily Director Movie Recommendations

## Overview
An iOS app and WidgetKit extension that delivers a daily movie recommendation curated by one of your 5 favorite directors. Built with SwiftUI, WidgetKit, and Firebase (Auth & Firestore). Users select 5 directors, then every local midnight the app picks a random movie from one of them and notifies the user and updates the widget.

## Features
- Onboarding: multi-select 5 directors from Firestore collection `directors`.
- Daily recommendation: random director + movie at midnight with local notification.
- Home‐screen widget: shows today's movie, deep‑links to Letterboxd.
- Firebase Auth (anonymous or real login) and Firestore for data storage.
- Optional Letterboxd API integration for automatic logging (OAuth 2.0).

## Requirements
- iOS 15.0+ / Xcode 14+
- Swift 5.7+
- SwiftUI, WidgetKit
- Firebase SDKs: Core, Auth, Firestore

## Setup
1. **Create** a new Xcode project named `DailyMovieApp` (App target, SwiftUI App lifecycle).
2. **Add** a WidgetKit target named `MovieRecommendationWidget`.
3. **Enable** an App Group (e.g. `group.com.yourapp.moviewidget`) on both targets under Signing & Capabilities.
4. **Download** `GoogleService-Info.plist` from Firebase console and add it to the App target.
5. **Integrate** Firebase via CocoaPods:
   ```bash
   cd <project directory>
   pod init
   ```
6. **Edit** the generated `Podfile` to include:
   ```ruby
   platform :ios, '15.0'
   use_frameworks!

   target 'DailyMovieApp' do
     pod 'Firebase/Core'
     pod 'Firebase/Auth'
     pod 'Firebase/Firestore'
   end

   target 'MovieRecommendationWidget' do
     # no pods needed
   end
   ```
7. **Install** pods:
   ```bash
   pod install
   open DailyMovieApp.xcworkspace
   ```
8. **Replace** the default SwiftUI files with the provided implementations for `DailyMovieApp.swift` and `MovieRecommendationWidget.swift`.
9. **Run** on device or simulator. On first launch, select 5 directors and enjoy daily recommendations and widget updates.

## Notes
- Replace anonymous Auth with real sign‑in for multi‑device sync.
- To enable automatic Letterboxd logging, obtain API keys and implement OAuth flow.
- SwiftUI Previews are included for fast UI iteration in Xcode canvas.

Happy coding!
