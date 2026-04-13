# 📍 Attendance Pulse

A GPS-based attendance tracking application built with **Flutter** and **Firebase**. Designed for students to mark and log their class attendance in real-time using precise geolocation, biometric verification, and an interactive map.

---

## ✨ Features

### 🔐 Authentication
- **Email & Password** sign-in / sign-up via Firebase Auth
- **Email verification** — users must verify their email before logging in
- **Biometric login** — fingerprint or device PIN authentication via `local_auth`
- User profile stored in Cloud Firestore (name, email, registration number, course)

### 📍 GPS Attendance
- Real-time GPS location detection using `geolocator`
- Reverse geocoding to display a human-readable address via `geocoding`
- Interactive **Google Maps** embed showing the student's exact pinpointed location
- Biometric re-verification required before signing attendance
- Attendance records saved to Firestore with coordinates, address, timestamp, and selected unit

### 📊 Reports & Analytics
- Real-time attendance log stream from Firestore
- Total classes attended counter
- Chronological history showing unit, timestamp, and logged location for each entry

### 📚 Unit Management
- Register academic units (unit code + unit name) stored per-student in Firestore
- View all registered units in a live-updating list
- Select a unit before marking attendance

### 👤 Profile
- Displays user info: full name, registration number, course, and email
- Avatar generated from user initials

### 🎨 UI / UX
- **Aurora background** with animated gradient effects
- **Glassmorphism** cards throughout the app
- Light & dark theme support following system preference
- Custom color system and Google Fonts typography

---

## 🏗️ Architecture

```
lib/
├── main.dart                        # App entry point & Firebase init
├── firebase_options.dart            # Generated Firebase config
├── core/
│   ├── theme/
│   │   ├── app_colors.dart          # Color palette constants
│   │   └── app_theme.dart           # Light & dark ThemeData
│   ├── utils/
│   │   └── biometric_helper.dart    # Biometric auth utility
│   └── widgets/
│       ├── aurora_background.dart   # Animated gradient background
│       └── glass_card.dart          # Glassmorphism card widget
├── features/
│   ├── auth/
│   │   ├── login_screen.dart        # Login (email + biometric)
│   │   └── signup_screen.dart       # Registration form
│   ├── attendance/
│   │   └── attendance_screen.dart   # Main screen — GPS, map, sign
│   ├── reports/
│   │   └── reports_screen.dart      # Attendance history & analytics
│   ├── units/
│   │   └── units_screen.dart        # Unit registration & listing
│   └── profile/
│       └── profile_screen.dart      # User profile display
└── services/
    └── auth_service.dart            # Firebase Auth + Firestore logic
```

---

## 🔧 Tech Stack

| Layer            | Technology                              |
| ---------------- | --------------------------------------- |
| Framework        | Flutter (Dart)                          |
| Authentication   | Firebase Auth + `local_auth` biometrics |
| Database         | Cloud Firestore                         |
| Location         | `geolocator` + `geocoding`              |
| Maps             | Google Maps Flutter SDK                 |
| Styling          | Material 3, Google Fonts                |
| State Management | `setState` (built-in)                   |

---

## 📦 Dependencies

```yaml
firebase_core: ^4.5.0
firebase_auth: ^6.2.0
cloud_firestore: ^6.1.3
local_auth: ^3.0.1
geolocator: ^13.0.2
geocoding: ^3.0.0
google_maps_flutter: ^2.10.0
google_fonts: ^8.0.2
shared_preferences: ^2.5.4
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `>=3.11.3`
- A Firebase project with **Auth** and **Firestore** enabled
- A Google Maps API key (for the map embed on Android/iOS)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd attendance_pulse
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add your `google-services.json` (Android) and/or `GoogleService-Info.plist` (iOS)
   - The project already includes a generated `firebase_options.dart`

4. **Add your Google Maps API key**
   - **Android:** `android/app/src/main/AndroidManifest.xml`
   - **iOS:** `ios/Runner/AppDelegate.swift`

5. **Run the app**
   ```bash
   flutter run
   ```

---

## 📱 Screens

| Screen       | Description                                              |
| ------------ | -------------------------------------------------------- |
| **Login**    | Email/password sign-in or biometric quick login          |
| **Sign Up**  | Registration with name, email, reg number, course        |
| **Attendance** | GPS location + map + unit selector + biometric verify  |
| **Reports**  | Attendance log history with analytics                    |
| **Units**    | Register and view academic units                         |
| **Profile**  | View personal details and avatar                         |

---

## 🔒 Permissions

- **Location** — required to determine the student's GPS coordinates
- **Biometrics** — fingerprint / device credential for identity verification
- **Internet** — Firebase communication

---

## 📄 License

This project is for educational purposes.
