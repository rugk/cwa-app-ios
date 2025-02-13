////
// 🦠 Corona-Warn-App
//

import Foundation
import NotificationCenter

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
	
	// MARK: - Init
	
	init(
		coronaTestService: CoronaTestService,
		eventCheckoutService: EventCheckoutService,
		healthCertificateService: HealthCertificateService,
		showHome: @escaping () -> Void,
		showTestResultFromNotification: @escaping (CoronaTestType) -> Void,
		showHealthCertificate: @escaping (Route) -> Void
	) {
		self.coronaTestService = coronaTestService
		self.eventCheckoutService = eventCheckoutService
		self.healthCertificateService = healthCertificateService
		self.showHome = showHome
		self.showTestResultFromNotification = showTestResultFromNotification
		self.showHealthCertificate = showHealthCertificate
	}
		
	// MARK: - Protocol UNUserNotificationCenterDelegate
	
	func userNotificationCenter(_: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		// Checkout overdue checkins.
		if notification.request.identifier.contains(LocalNotificationIdentifier.checkout.rawValue) {
			eventCheckoutService.checkoutOverdueCheckins()
		}

		completionHandler([.alert, .badge, .sound])
	}

	func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		switch response.notification.request.identifier {
		
		case ActionableNotificationIdentifier.riskDetection.identifier,
			 ActionableNotificationIdentifier.deviceTimeCheck.identifier:
			showHome()

		case ActionableNotificationIdentifier.pcrWarnOthersReminder1.identifier,
			 ActionableNotificationIdentifier.pcrWarnOthersReminder2.identifier:
			showPositivePCRTestResultIfNeeded()

		case ActionableNotificationIdentifier.antigenWarnOthersReminder1.identifier,
			 ActionableNotificationIdentifier.antigenWarnOthersReminder2.identifier:
			showPositiveAntigenTestResultIfNeeded()

		case ActionableNotificationIdentifier.testResult.identifier:
			let testIdentifier = ActionableNotificationIdentifier.testResult.identifier
			let testTypeIdentifier = ActionableNotificationIdentifier.testResultType.identifier

			guard let testResultRawValue = response.notification.request.content.userInfo[testIdentifier] as? Int,
				  let testResult = TestResult(serverResponse: testResultRawValue),
				  let testResultTypeRawValue = response.notification.request.content.userInfo[testTypeIdentifier] as? Int,
				  let testResultType = CoronaTestType(rawValue: testResultTypeRawValue) else {
				showHome()
				return
			}

			switch testResult {
			case .positive, .negative:
				showTestResultFromNotification(testResultType)
			case .invalid:
				showHome()
			case .expired, .pending:
				assertionFailure("Expired and Pending Test Results should not trigger the Local Notification")
			}
		default:
			// special action where we need to extract data from identifier
			checkForLocalNotificationsActions(response.notification.request.identifier)
		}
		completionHandler()
	}

	// MARK: - Internal
	
	// Internal for testing
	func extract(_ prefix: String, from: String) -> (HealthCertifiedPerson, HealthCertificate)? {
		guard from.hasPrefix(prefix) else {
			return nil
		}
		return findHealthCertificate(String(from.dropFirst(prefix.count)))
	}
	
	// MARK: - Private
	
	private let coronaTestService: CoronaTestService
	private let eventCheckoutService: EventCheckoutService
	private let healthCertificateService: HealthCertificateService
	private let showHome: () -> Void
	private let showTestResultFromNotification: (CoronaTestType) -> Void
	private let showHealthCertificate: (Route) -> Void
	
	private func showPositivePCRTestResultIfNeeded() {
		if let pcrTest = coronaTestService.pcrTest,
		   pcrTest.positiveTestResultWasShown {
			showTestResultFromNotification(.pcr)
		}
	}

	private func showPositiveAntigenTestResultIfNeeded() {
		if let antigenTest = coronaTestService.antigenTest,
		   antigenTest.positiveTestResultWasShown {
			showTestResultFromNotification(.antigen)
		}
	}

	private func checkForLocalNotificationsActions(_ identifier: String) {
		if let (certifiedPerson, healthCertificate) = extract(LocalNotificationIdentifier.certificateExpired.rawValue, from: identifier) {
			let route = Route(
				healthCertifiedPerson: certifiedPerson,
				healthCertificate: healthCertificate
			)
			showHealthCertificate(route)
		} else if let (certifiedPerson, healthCertificate) = extract(LocalNotificationIdentifier.certificateExpiringSoon.rawValue, from: identifier) {
			let route = Route(
				healthCertifiedPerson: certifiedPerson,
				healthCertificate: healthCertificate
			)
			showHealthCertificate(route)
		} else if let (certifiedPerson, healthCertificate) = extract(LocalNotificationIdentifier.certificateInvalid.rawValue, from: identifier) {
			let route = Route(
				healthCertifiedPerson: certifiedPerson,
				healthCertificate: healthCertificate
			)
			showHealthCertificate(route)
		}
	}
	
	private func findHealthCertificate(_ identifier: String) -> (HealthCertifiedPerson, HealthCertificate)? {
		for person in healthCertificateService.healthCertifiedPersons.value {
			if let certificate = person.$healthCertificates.value
				.first(where: { $0.uniqueCertificateIdentifier == identifier }) {
				return (person, certificate)
			}
		}
		return nil
	}
}
