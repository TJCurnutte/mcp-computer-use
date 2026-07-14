import Foundation

/// Current step of the onboarding flow.
enum OnboardingState: Equatable {
    case idle
    case moveToApplications
    case permissions
    case installConfig
    case test
    case complete
}

extension OnboardingState {
    var title: String {
        switch self {
        case .idle:
            return "Getting Started"
        case .moveToApplications:
            return "Move to Applications"
        case .permissions:
            return "Permissions"
        case .installConfig:
            return "Install Config"
        case .test:
            return "Test Connection"
        case .complete:
            return "All Set"
        }
    }

    var buttonTitle: String {
        switch self {
        case .idle:
            return "Start"
        case .moveToApplications:
            return "Check Applications Folder"
        case .permissions:
            return "Check Permissions"
        case .installConfig:
            return "Install Config"
        case .test:
            return "Run Test"
        case .complete:
            return "Finish"
        }
    }
}
