////
// 🦠 Corona-Warn-App
//

import Foundation

struct RegionStatisticsData {

	// MARK: - Init

	init(
		region: LocalStatisticsRegion,
		updatedAt: Int64? = nil,
		sevenDayIncidence: SAP_Internal_Stats_SevenDayIncidenceData? = nil
	) {
		self.region = region
		self.updatedAt = updatedAt
		self.sevenDayIncidence = sevenDayIncidence
	}

	init(
		region: LocalStatisticsRegion,
		localStatisticsData: [SAP_Internal_Stats_LocalStatistics]
	) {
		self.region = region

		switch region.regionType {
		case .federalState:
			let federalStateData = localStatisticsData
				.flatMap { $0.federalStateData }
				.first {
					$0.federalState.rawValue == Int(region.id)
				}

			updatedAt = federalStateData?.updatedAt
			sevenDayIncidence = federalStateData?.sevenDayIncidence
		case .administrativeUnit:
			let administrativeUnitData = localStatisticsData
				.flatMap { $0.administrativeUnitData }
				.first {
					$0.administrativeUnitShortID == Int(region.id) ?? 0
				}

			updatedAt = administrativeUnitData?.updatedAt
			sevenDayIncidence = administrativeUnitData?.sevenDayIncidence
		}
	}

	// MARK: - Internal

	var region: LocalStatisticsRegion
	var updatedAt: Int64?
	var sevenDayIncidence: SAP_Internal_Stats_SevenDayIncidenceData?

}
