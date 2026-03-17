# 🚀 Rast (راست)
**A Lightweight macOS Utility for Seamless RTL Text Handling**

Rast is a productivity tool designed for macOS users who frequently work with Right-to-Left (RTL) languages like Persian, Arabic, and Hebrew. It solves the common frustration of text alignment and rendering issues in non-RTL-friendly applications by providing a floating, instant-access RTL workspace.

---

## ✨ Features

- **Instant Detection**: Automatically detects text selection in any application and offers a quick floating bridge.
- **Global Shortcuts**: 
  - `Ctrl + Option + R`: Instantly capture selection and open the RTL Pad.
  - `Cmd + Option + R`: Alternative shortcut for immediate access.
- **RTL-Optimized Pad**: A minimalist, beautiful text editor with built-in support for RTL fonts (like Vazirmatn).
- **Clipboard Integration**: Automatically monitors your clipboard to provide quick RTL conversions.
- **Menu Bar Access**: Lightweight status item for quick actions and permission management.
- **Smart UI**: A non-intrusive floating bridge that appears only when you need it and disappears when you're done.

---

## 🛠 Technical Architecture

Rast is built with **Swift 5** and **SwiftUI**, adhering to **Clean Architecture** principles to ensure professional code quality and maintainability.

### Project Structure
```text
Rast/
├── Sources/
│   ├── App/          # Application lifecycle and Menu Bar management
│   ├── Core/         # Business logic layer
│   │   ├── Monitors/ # Low-level event processing (Keyboard, Selection)
│   │   ├── Services/ # System integrations (Clipboard, Simulate Cmd+C)
│   │   └── Helpers/  # Infrastructure utilities (Accessibility API)
│   └── UI/           # Presentation layer
│       ├── Views/    # SwiftUI RTL-focused components
│       └── Controllers/ # Floating window management
└── Resources/        # Assets and metadata
```

### Key Technical Implementations
- **Accessibility API (AXUIElement)**: Used to directly read text selection from the frontmost application without relying on the clipboard when possible.
- **Carbon HotKeys**: Low-level global shortcut implementation for high performance and reliability.
- **Event Monitors**: Global and local event monitoring to manage floating UI lifecycle (dismiss on outside click/ESC).
- **Core Graphics Events**: Programmatic `Cmd+C` simulation as a robust fallback for applications that don't fully support the Accessibility API.

---

## 🚀 Installation & Setup

1. **Build**: Open `Rast.xcodeproj` in Xcode and build (Target: macOS 13.0+).
2. **Accessibility Permission**:
   - Upon first launch, Rast will request Accessibility access.
   - Go to `System Settings > Privacy & Security > Accessibility`.
   - Enable **Rast**.
   - *Note: This is required to read text selection and listen for global shortcuts.*

## 📦 GitHub Releases

Rast can now publish ready-to-download binaries on the GitHub `Releases` page.

### Automatic release flow
- Push a tag like `v1.0.1`.
- GitHub Actions builds the macOS app.
- The workflow uploads both `.dmg` and `.zip` files to the matching Release page.

### Local packaging
If you want to build the release artifacts locally first:

```bash
./package_release.sh 1.0.1
```

The generated files will be placed in `dist/`.

---

## 🤝 Contribution

Contributions are welcome! Whether it's adding a new feature, fixing a bug, or improving the UI, feel free to open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---
**Developed with ❤️ for the RTL Community.**
