import Foundation

/// Methods the onboarding UI calls on its controller.
protocol OnboardingDelegate: AnyObject {
    func onboardingDidRequestMoveToApplications()
    func onboardingDidRequestPermissions()
    func onboardingDidRequestInstallConfig()
    func onboardingDidRequestTest()
    func onboardingDidFinish()
}
