# GoodUIKitCoordinator

A lightweight, flexible coordinator pattern implementation for UIKit applications, designed to simplify navigation flow management in iOS apps.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platforms-iOS%2013.0%20%7C%20macOS%2011.0-blue.svg)](https://apple.com/ios)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/GoodRequest/GoodUIKitCoordinator/blob/main/LICENSE)

## Overview

GoodUIKitCoordinator provides a robust implementation of the coordinator pattern for UIKit-based iOS applications. It helps you separate navigation logic from view controllers, making your code more maintainable, testable, and easier to understand.

## Features

- Simplified navigation flow management
- Support for complex navigation hierarchies
- Easy parent-child coordinator relationships
- Built-in support for common navigation actions (push, pop, present, dismiss)
- Integrated support for Safari, universal links, and system apps
- Messaging capabilities (SMS, email)
- Combine integration for reactive programming

## Requirements

- iOS 13.0+ / macOS 11.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add GoodUIKitCoordinator to your project through Swift Package Manager:

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/GoodRequest/GoodUIKitCoordinator.git`
3. Select the version or branch you want to use

Alternatively, add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/GoodRequest/GoodUIKitCoordinator.git", from: "1.0.0")
]
```

## Usage

### Basic Implementation

1. Create a coordinator by subclassing `GoodCoordinator` with your custom step enum:

```swift
// Define your navigation steps
enum AppStep {
    case dashboard
    case profile
    case settings
    case details(item: Item)
}

// Create your coordinator
class AppCoordinator: GoodCoordinator<AppStep> {
    
    override func navigate(to step: AppStep) -> StepAction {
        switch step {
        case .dashboard:
            let viewController = DashboardViewController()
            return .push(viewController)
            
        case .profile:
            let viewController = ProfileViewController()
            return .present(viewController)
            
        case .settings:
            let viewController = SettingsViewController()
            return .push(viewController)
            
        case .details(let item):
            let viewController = DetailsViewController(item: item)
            return .push(viewController)
        }
    }
}
```

2. Initialize and start your coordinator:

```swift
let navigationController = UINavigationController()
let coordinator = AppCoordinator(rootViewController: navigationController)
coordinator.start()

// Navigate to a specific step
coordinator.perform(step: .dashboard)
```

### Nested Coordinators

You can create hierarchies of coordinators for complex navigation flows:

```swift
class ProfileCoordinator: GoodCoordinator<ProfileStep> {
    // Implementation
}

class AppCoordinator: GoodCoordinator<AppStep> {
    
    override func navigate(to step: AppStep) -> StepAction {
        switch step {
        case .profile:
            let profileCoordinator = ProfileCoordinator(parentCoordinator: self)
            profileCoordinator.start()
            profileCoordinator.perform(step: .showProfile)
            return .none
            
        // Other cases
        }
    }
}
```

### Navigation Between Coordinators

Use the static `execute` method to navigate between coordinators:

```swift
// From any view controller
@IBAction func showSettings() {
    GoodCoordinator.execute(
        step: .settings,
        on: SettingsCoordinator.self,
        from: coordinator
    )
}
```

## License

GoodUIKitCoordinator is available under the MIT license. See the [LICENSE](LICENSE) file for more info.