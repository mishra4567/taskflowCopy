# TaskFlow

A cross-platform task management app built with [Flutter](https://flutter.dev), supporting Android, iOS, Web, Linux, macOS, and Windows from a single codebase.

> **Repo:** [mishra4567/taskflowCopy](https://github.com/mishra4567/taskflowCopy)

---

## 📋 Overview

TaskFlow is a Flutter project for managing tasks across multiple platforms. The codebase currently ships with platform-specific configuration for all major Flutter targets, meaning it can be built and run on mobile, desktop, and web without additional setup.

## ✨ Features

> _Add a short list of the app's actual features here — e.g. task creation, reminders, categories, sync, etc. This section is a placeholder since feature details weren't available from the repo listing alone._

## ⚙️ How It Works

TaskFlow is built around an **extension-based architecture** — rather than being a single fixed to-do app, it works as a shell that loads installable extensions, each adding its own functionality to the app.

### Extensions

- The app ships with default extensions installed out of the box:
  - **TODO List** — core task management functionality
  - **Calendar** — date/schedule-based view of tasks
- Additional extensions can be installed on top of these defaults, allowing the app's feature set to grow without changing the core.
- Users/developers can also **build and add their own custom extensions**, making TaskFlow extensible beyond the built-in modules.

### Theming

TaskFlow supports multiple display modes that control the app's appearance:

- **Dark mode** — dark color scheme throughout the app
- **Light mode** — bright/default color scheme
- **System Detect** — automatically follows the operating system's current theme setting (dark or light), switching as the OS preference changes

> _If extensions have a defined structure (e.g. a manifest file, required interface, or plugin folder convention), add that detail here so contributors know how to build new ones._

## 🗂️ Project Structure

```
taskflowCopy/
├── android/          # Android platform-specific project files
├── ios/              # iOS platform-specific project files
├── linux/            # Linux desktop platform files
├── macos/            # macOS desktop platform files
├── windows/          # Windows desktop platform files
├── web/              # Web platform files
├── lib/              # Main Dart application source code
├── test/             # Automated tests
├── assets/
│   └── icon/         # App icon assets
├── backup/           # Backup files
├── .metadata         # Flutter tooling metadata
├── analysis_options.yaml  # Dart/Flutter linter configuration
├── bug.txt           # Known issues / bug notes
├── pubspec.yaml       # Project dependencies and metadata
├── pubspec.lock       # Locked dependency versions
└── README.md
```

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured
- A configured emulator/simulator, or a physical device, for mobile targets
- Platform-specific toolchains as needed:
  - Android Studio + Android SDK (for Android)
  - Xcode (for iOS/macOS, requires a Mac)
  - Visual Studio with C++ workload (for Windows)
  - Standard Linux build tools (for Linux)

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/mishra4567/taskflowCopy.git
   cd taskflowCopy
   ```
2. Install dependencies
   ```bash
   flutter pub get
   ```
3. Run the app
   ```bash
   flutter run
   ```
   To target a specific platform:
   ```bash
   flutter run -d chrome     # Web
   flutter run -d windows    # Windows
   flutter run -d macos      # macOS
   flutter run -d linux      # Linux
   ```

### Running Tests

```bash
flutter test
```

## 🐛 Known Issues

See [`bug.txt`](./bug.txt) for currently tracked bugs and notes.

## 🛠️ Built With

- [Flutter](https://flutter.dev) — UI toolkit for building natively compiled apps
- [Dart](https://dart.dev) — Programming language

## 📚 Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## 📄 License

> _No license specified yet. Consider adding a `LICENSE` file to clarify usage terms._

## 🤝 Contributing

> _Add contribution guidelines here if this project accepts external contributions._
