# WalkAnywhere

A beautiful iOS walking route tracker with a liquid glass UI design. Plan walking routes, track your daily steps, and visualize your progress with an elegant glassmorphism interface.

![WalkAnywhere Screenshot](Screenshot%202026-03-24%20at%2008.32.39.png)

## Features

### 🗺️ Route Planning
- **Interactive Map Interface** - Tap to place start and end points
- **Automatic Route Calculation** - Uses Apple Maps walking directions
- **Hybrid Routing** - Falls back to straight-line connections when needed
- **Route Details Drawer** - Collapsible drawer showing distance, time, and step estimates

### 👣 Step Tracking
- **HealthKit Integration** - Tracks daily steps automatically
- **Progress Visualization** - Beautiful progress bars showing route completion
- **Step History** - View past 30 days of step data
- **Real-time Updates** - Live progress tracking for active routes

### 🎨 Beautiful Design
- **Liquid Glass UI** - Modern glassmorphism design throughout
- **Custom Navigation** - Glassy pill-shaped navigation titles
- **Smooth Animations** - Spring animations for drawer and transitions
- **Dark/Light Mode** - Adapts to system appearance

### 📱 Core Functionality
- **Save Multiple Routes** - Create and store unlimited walking routes
- **Main Route System** - Star your favorite route for quick access
- **Route Management** - Edit, delete, and organize your routes
- **Progress Persistence** - Automatically saves your walking progress

## Technical Details

### Built With
- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - For persistent data storage
- **MapKit** - Interactive maps and routing
- **HealthKit** - Step counting and health data
- **iOS 26.2+** - Latest iOS features

### Architecture
- **MVVM Pattern** - Clean separation of concerns
- **Component-Based UI** - Reusable glassy components
- **Async/Await** - Modern Swift concurrency
- **Observable Objects** - Reactive data flow

### Project Structure
```
walkanywhere/
├── Views/
│   ├── MainRoute/          # Current journey view
│   ├── CreateRoute/        # Map route creation
│   └── Components/         # Reusable UI components
│       ├── GlassyNavigationTitle.swift
│       ├── GlassyButton.swift
│       ├── RouteInfoCard.swift
│       ├── RouteDetailsDrawer.swift
│       └── DebugMenuSheet.swift
├── SavedRoutesView.swift   # Routes list
├── StepHistoryView.swift   # Step history
├── RouteManager.swift      # Route data management
├── HealthKitManager.swift  # HealthKit integration
└── Models/
    ├── SavedRoute.swift
    └── StepData.swift
```

## Getting Started

### Requirements
- Xcode 15.0+
- iOS 26.2+ Simulator or Device
- Apple Developer Account (for HealthKit)

### Build Instructions

Build for debug:
```bash
xcodebuild -project walkanywhere.xcodeproj -scheme walkanywhere -configuration Debug build
```

Build for release:
```bash
xcodebuild -project walkanywhere.xcodeproj -scheme walkanywhere -configuration Release build
```

Clean build:
```bash
xcodebuild -project walkanywhere.xcodeproj -scheme walkanywhere clean
```

### Running the App
1. Open `walkanywhere.xcodeproj` in Xcode
2. Select your target device/simulator
3. Press `Cmd + R` to build and run
4. Grant HealthKit permissions when prompted

## Usage

### Creating a Route
1. Navigate to "My Routes"
2. Tap the + button
3. Tap two points on the map
4. Review the calculated route
5. Tap "Save Route" and enter a name

### Setting a Main Route
1. Go to "My Routes"
2. Tap the star icon next to any route
3. View your progress in "Current Journey"

### Tracking Progress
- Your daily steps automatically count toward your main route
- Progress persists even when changing routes
- Complete routes are marked with a checkmark

## Design System

### Glassmorphism Components
All UI components follow a consistent liquid glass design:
- **Background**: `.ultraThinMaterial` blur
- **Overlay**: White gradient (0.3 → 0.1 opacity)
- **Border**: Gradient stroke (white 0.5 → 0.2 opacity)
- **Shadow**: Soft black shadow (0.1 opacity)
- **Corners**: 30pt for pills, 16pt for cards

### Code Style
- **Indentation**: 2 spaces
- **Naming**: Descriptive, Swift-style camelCase
- **Comments**: Inline documentation for complex logic

## Development

See [CLAUDE.md](CLAUDE.md) for detailed project configuration and architecture notes.

See [PROMPTS.md](PROMPTS.md) for complete development history and user requests.

## License

All rights reserved.

## Credits

Designed and built by Zachary Upstone, 2026
