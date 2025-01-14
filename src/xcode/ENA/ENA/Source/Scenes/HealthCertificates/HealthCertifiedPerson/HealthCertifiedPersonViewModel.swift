////
// 🦠 Corona-Warn-App
//

import UIKit
import Contacts
import OpenCombine

final class HealthCertifiedPersonViewModel {

	// MARK: - Init

	init(
		healthCertificateService: HealthCertificateService,
		healthCertifiedPerson: HealthCertifiedPerson,
		healthCertificateValueSetsProvider: VaccinationValueSetsProviding,
		dismiss: @escaping () -> Void,
		didTapValidationButton: @escaping (HealthCertificate, @escaping (Bool) -> Void) -> Void
	) {
		self.healthCertificateService = healthCertificateService
		self.healthCertifiedPerson = healthCertifiedPerson
		self.healtCertificateValueSetsProvider = healthCertificateValueSetsProvider

		self.didTapValidationButton = didTapValidationButton
		
		constructHealthCertificateCellViewModels(for: healthCertifiedPerson)

		healthCertifiedPerson.objectDidChange
			.sink { [weak self] person in
				self?.constructHealthCertificateCellViewModels(for: person)
				
				guard !person.healthCertificates.isEmpty else {
					// Prevent trigger reload if we the person was removed before because we removed their last certificate.
					self?.triggerReload = false
					dismiss()
					return
				}

				self?.triggerReload = true
			}
			.store(in: &subscriptions)

		healthCertifiedPerson.$gradientType
			.sink { [weak self] in
				self?.gradientType = $0
			}
			.store(in: &subscriptions)

		// load certificate value sets
		healthCertificateValueSetsProvider.latestVaccinationCertificateValueSets()
			.sink(
				receiveCompletion: { _ in },
				receiveValue: { _ in }
			)
			.store(in: &subscriptions)
	}

	// MARK: - Internal

	enum TableViewSection: Int, CaseIterable {
		case header
		case qrCode
		case person
		case vaccinationHint
		case certificates

		static var numberOfSections: Int {
			allCases.count
		}

		static func map(_ section: Int) -> TableViewSection {
			guard let section = TableViewSection(rawValue: section) else {
				fatalError("unsupported tableView section")
			}
			return section
		}
	}

	let headerCellViewModel: HealthCertificateSimpleTextCellViewModel = {
		HealthCertificateSimpleTextCellViewModel(
			backgroundColor: .clear,
			textColor: .enaColor(for: .textContrast),
			textAlignment: .center,
			text: AppStrings.HealthCertificate.Person.title,
			topSpace: 42.0,
			font: .enaFont(for: .headline),
			accessibilityTraits: .staticText
		)
	}()

	@OpenCombine.Published private(set) var gradientType: GradientView.GradientType = .lightBlue(withStars: true)
	@OpenCombine.Published private(set) var triggerReload: Bool = false
	@OpenCombine.Published private(set) var updateError: Error?

	var qrCodeCellViewModel: HealthCertificateQRCodeCellViewModel {
		guard let mostRelevantHealthCertificate = healthCertifiedPerson.mostRelevantHealthCertificate
			else {
			fatalError("Cell cannot be shown without a health certificate")
		}

		return HealthCertificateQRCodeCellViewModel(
			mode: .overview,
			healthCertificate: mostRelevantHealthCertificate,
			accessibilityText: AppStrings.HealthCertificate.Person.QRCodeImageDescription,
			onValidationButtonTap: { [weak self] healthCertificate, loadingStateHandler in
				self?.didTapValidationButton(healthCertificate, loadingStateHandler)
			}
		)
	}

	var vaccinationHintCellViewModel: HealthCertificateSimpleTextCellViewModel {
		let text: String

		switch healthCertifiedPerson.vaccinationState {
		case .partiallyVaccinated:
			text = AppStrings.HealthCertificate.Person.partiallyVaccinated
		case .fullyVaccinated(daysUntilCompleteProtection: let daysUntilCompleteProtection):
			text = String(
				format: AppStrings.HealthCertificate.Person.daysUntilCompleteProtection,
				daysUntilCompleteProtection
			)
		case .notVaccinated, .completelyProtected:
			fatalError("Cell cannot be shown in any other vaccination state than .partiallyVaccinated or .fullyVaccinated")
		}

		return HealthCertificateSimpleTextCellViewModel(
			backgroundColor: .enaColor(for: .cellBackground2),
			textAlignment: .left,
			text: text,
			topSpace: 16.0,
			font: .enaFont(for: .body),
			borderColor: .enaColor(for: .hairline),
			accessibilityTraits: .staticText
		)
	}

	var vaccinationHintIsVisible: Bool {
		switch healthCertifiedPerson.vaccinationState {
		case .partiallyVaccinated, .fullyVaccinated:
			return true
		case .notVaccinated, .completelyProtected:
			return false
		}
	}

	var preferredPersonCellModel: PreferredPersonCellModel {
		PreferredPersonCellModel(
			healthCertifiedPerson: healthCertifiedPerson,
			healthCertificateService: healthCertificateService
		)
	}

	func numberOfItems(in section: TableViewSection) -> Int {
		switch section {
		case .header:
			return 1
		case .qrCode:
			return 1
		case .vaccinationHint:
			return vaccinationHintIsVisible ? 1 : 0
		case .person:
			return 1
		case .certificates:
			return healthCertifiedPerson.healthCertificates.count
		}
	}

	func heightForFooter(in section: TableViewSection) -> CGFloat {
		switch section {
		case .certificates:
			return 12
		default:
			return 0
		}
	}

	func healthCertificateCellViewModel(row: Int) -> HealthCertificateCellViewModel {
		return healthCertificateCellViewModels[row]
	}

	func healthCertificate(for indexPath: IndexPath) -> HealthCertificate? {
		guard TableViewSection.map(indexPath.section) == .certificates else {
			return nil
		}

		return healthCertificateCellViewModels[safe: indexPath.row]?.healthCertificate
	}

	func canEditRow(at indexPath: IndexPath) -> Bool {
		return TableViewSection.map(indexPath.section) == .certificates
	}

	func removeHealthCertificate(at indexPath: IndexPath) {
		guard TableViewSection.map(indexPath.section) == .certificates else {
			return
		}

		healthCertificateService.removeHealthCertificate(healthCertificateCellViewModels[indexPath.row].healthCertificate)
	}

	// MARK: - Private

	private let healthCertifiedPerson: HealthCertifiedPerson
	private let healthCertificateService: HealthCertificateService
	private let healtCertificateValueSetsProvider: VaccinationValueSetsProviding

	private let didTapValidationButton: (HealthCertificate, @escaping (Bool) -> Void) -> Void

	private var subscriptions = Set<AnyCancellable>()

	private var healthCertificateCellViewModels = [HealthCertificateCellViewModel]()

	private func constructHealthCertificateCellViewModels(for person: HealthCertifiedPerson) {
		let sortedHealthCertificates = person.healthCertificates.sorted(by: >)
		healthCertificateCellViewModels = sortedHealthCertificates.map {
			HealthCertificateCellViewModel(
				healthCertificate: $0,
				healthCertifiedPerson: person
			)
		}
	}
}
