# 🏆 ScoreKeeper

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square)](https://developer.apple.com/swift/)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=flat-square)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-informational.svg?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![XcodeGen](https://img.shields.io/badge/Project-XcodeGen-brightgreen.svg?style=flat-square)](https://github.com/yonaskolb/XcodeGen)

A premium, modern, and haptics-rich score tracker for card games. Designed specifically for Italian card game classics (such as Scopa, Briscola, Bisca, Ciccopaolo, and Scala 40), **ScoreKeeper** features a stunning dark-mode interface, fluid animations, and custom haptic feedback profiles to elevate your tabletop game nights.

---

> [!IMPORTANT]
> ### 🧮 Featured: Primiera Calculator
> ScoreKeeper now includes a fully integrated, interactive [PrimieraCalculatorView](file:///Users/giuseppedambrosi/Antigravity/ScoreApp/ScoreKeeper/Sources/PrimieraCalculatorView.swift) to solve score calculations instantly:
> - **Smart Pre-fill:** Automatically pre-selects the **7 of Denari** (Settebello) for whichever player won the Settebello card.
> - **Visual Suit Selection:** Select cards for Denari (🪙), Coppe (🏆), Spade (⚔️), and Bastoni (🪵) using color-coded grids.
> - **Automatic Scoring:** Computes Primiera points in real time using traditional card weights (7 = 21, 6 = 18, Asso = 16, 5 = 15, 4 = 14, 3 = 13, 2 = 12, face cards = 10).
> - **Direct Apply:** One-click assignment of the Primiera point back to the active round in [ScopaView](file:///Users/giuseppedambrosi/Antigravity/ScoreApp/ScoreKeeper/Sources/ScopaView.swift) and [CiccopaoloView](file:///Users/giuseppedambrosi/Antigravity/ScoreApp/ScoreKeeper/Sources/CiccopaoloView.swift).

## ✨ Features

- **🧮 Interactive Primiera Solver:** A specialized calculator ([PrimieraCalculatorView](file:///Users/giuseppedambrosi/Antigravity/ScoreApp/ScoreKeeper/Sources/PrimieraCalculatorView.swift)) to instantly determine the Primiera winner by comparing the highest card per suit.
- **📱 Premium Glassmorphic Design:** Apple-inspired dark aesthetic, utilizing a curated color palette (pitch black, graphite cards, gold accents) optimized for high contrast and readability around the gaming table.
- **⚡ Tactile Haptics:** Custom-engineered haptic feedback utilizing `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator`. Experience subtle ticks on adjustments, success feedback on round wins, and a custom **Tap-Tap-Tap-BOOM** sequence upon winning a game.
- **🔄 Session Persistence:** Built-in local storage that automatically saves your active sessions and game history, ensuring you can resume a match even if the app restarts.
- **👥 Player Directory:** Maintain a local roster of players with customizable names, tracking their participation and status.
- **🎮 Game-Specific Scorers:** Custom scoring sheets designed around the unique rules of popular Italian card games instead of generic point counters.

---

## 🃏 Supported Games

| Game | Description | Score Tracking Mechanics |
| :--- | :--- | :--- |
| **Scopa** | Classic Italian card game | Tracks points for *Carte* (Cards), *Primiera*, *Settebello*, *Denari* (Coins), and individual *Scope* (Sweeps). |
| **Scala 40** | Popular card meld game | Supports custom target scores (e.g., 101/201), round-by-round point input, player elimination status, and re-entries. Managed via [ScalaQuarantaView](file:///Users/giuseppedambrosi/Antigravity/ScoreApp/ScoreKeeper/Sources/ScalaQuarantaView.swift). |
| **Briscola** | Trick-taking game | Simple interface to track score out of the traditional 120-point deck total. |
| **Bisca** | Multi-player survival game | Elimination-based mode where players start with a set number of "lives". Last player standing wins. |
| **Ciccopaolo** | Advanced Scopa variant | Features specialized score sheets tracking *Carte*, *Primiera*, *Settebello*, *Denari* (updated from *Mazzo*), and sweeps. Supports best-of-3 tournament rounds. |
| **Standard Points** | General card/board games | A clean, round-by-round point logger suitable for any tabletop game. |


---

## 🛠 Tech Stack

- **Framework:** SwiftUI
- **Language:** Swift 6.0 (Swift Concurrency structured)
- **Minimum Target:** iOS 17.0+
- **Project Structure:** Generated via [XcodeGen](https://github.com/yonaskolb/XcodeGen) to maintain clean Git histories and avoid merge conflicts on `.xcodeproj` files.

---

## 🚀 Getting Started

### Prerequisites
You need **Xcode 15+** (supporting Swift 6) and **XcodeGen** installed. If you don't have XcodeGen, install it via Homebrew:
```bash
brew install xcodegen
```

### Build and Run
1. Clone the repository.
2. In the project root directory, run XcodeGen to generate the `.xcodeproj` file:
   ```bash
   xcodegen generate
   ```
3. Open the generated project:
   ```bash
   open ScoreKeeper.xcodeproj
   ```
4. Choose your target simulator or device (iOS 17.0+) and press **Cmd + R** to run!

---

## 🗺 Future Roadmap

We want to expand ScoreKeeper to become the ultimate tabletop companion. Here is what is planned:

### 🃏 More Games
- **Tressette:** Custom scoring suite including *Napola* (Ace, Two, Three of the same suit) and declaration bonus tracking.
- **Burraco:** Support for meld-based card tracking, wildcards, and clean/dirty burraco calculations.
- **Machiavelli & Ramino:** Round-based penalty trackers and phase-completion checkmarks.
- **Custom Game Engine:** Create custom rule presets (e.g. choose target scores, add custom bonus fields, or toggles for round/elimination types).

### 🤖 Android Support
- Bring the signature dark-mode experience to the Android ecosystem.
- Build a native **Jetpack Compose** companion app.
- Port the rich haptic engine to Android's `Vibrator` and `VibratorManager` API to ensure the tactile game feel remains consistent.
- Share model logic via Kotlin Multiplatform (KMP) or design synchronized state databases.

### 🌐 Connectivity & Smart Features
- **Local Multiplayer Sync:** Use Apple's *Multipeer Connectivity* and Android's *Nearby Connections* to sync the scoreboard in real time across multiple screens so every player can see the score on their own phone.
- **Apple Watch Companion:** View active scores directly from your wrist.
- **Camera Card Counter:** Implement a Vision-based card scanner to automatically count Scopa points (e.g. counting the number of diamonds/denari and scanning the Settebello) at the end of a round using the camera.
- **Analytics Dashboard:** Visual charts, winning streaks, head-to-head records, and player performance history.