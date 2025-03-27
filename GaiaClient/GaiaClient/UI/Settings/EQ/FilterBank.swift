//
//  © 2019-2020 Qualcomm Technologies, Inc. and/or its subsidiaries. All rights reserved.
//

import Foundation
import GaiaCore
import PluginBase

struct GraphPoint {
    let result: Double
    let frequency: Double
}

typealias GraphCurve = [GraphPoint]

struct GraphData {
    let filterCurves: [GraphCurve]
    let totalCurve: GraphCurve
}

class FilterBank {
    static let numberOfFilters = 5

    private var filters = [BiQuadFilter] ()
    var frequency: Double = 48000.0 {
        didSet {
            filters.forEach { filter in
                filter.fs = frequency
            }
        }
    }

    var pregain: Double = 0.0

    var count: Int {
        return filters.count
    }

    required init(bands: [EQUserBandInfo]) {
        filters = [BiQuadFilter] ()
        frequency = 48000.0
        for band in bands {
            let filter = BiQuadFilter()
            filter.filterType = band.filterType
            filter.fc = Double(band.frequency)
            filter.gain = band.gain
            filter.q = band.q

            filters.append(filter)
        }
    }

    convenience init() {
        self.init(bands: [])
    }

    /*
    required init(from decoder:Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        filters = try values.decode([BiQuadFilter].self, forKey: .filters)
        frequency = try values.decode(Double.self, forKey: .frequency)
        pregain = try values.decode(Double.self, forKey: .pregain)
    }
 */
}

/*
extension FilterBank:Codable {
    private enum CodingKeys: String, CodingKey {
        case filters
        case frequency
        case pregain
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(filters, forKey: .filters)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(pregain, forKey: .pregain)
    }
}
 */

extension FilterBank {
    subscript(_ at: Int) -> BiQuadFilter {
        assert(at < filters.count)
        return filters[at]
    }

    private func dbGain(frequency: Double) -> Double {
        let gain = filters.reduce(0.0, { $0 + $1.calcDbGain(freq: frequency) })
        return gain
    }

    func generateDbGainGraph(frequencies: [Double]) -> GraphData {
		var totalGainCurve = GraphCurve()
        var filterGainCurves = filters.map({ _ in
            return GraphCurve()
        })

        frequencies.forEach { frequency in
            var totalGain = 0.0
            for filterIndex in 0 ..< filters.count {
            let filter = filters[filterIndex]
                let gain = filter.calcDbGain(freq: frequency)
                totalGain = totalGain + gain
                filterGainCurves[filterIndex].append(GraphPoint(result: gain, frequency: frequency))
            }
            totalGainCurve.append(GraphPoint(result: totalGain + pregain, frequency: frequency))
        }

		return GraphData(filterCurves: filterGainCurves, totalCurve: totalGainCurve)
    }

    func generatePhaseGraph(frequencies: [Double]) -> GraphData {
        var totalPhaseCurve = GraphCurve()
        var filterPhasesCurves = filters.map({ _ in
            return GraphCurve()
        })

        frequencies.forEach { frequency in
            var totalPhase = 0.0
            for filterIndex in 0 ..< filters.count {
                let filter = filters[filterIndex]
                let phase = filter.calcPhase(freq: frequency)
                totalPhase = totalPhase + phase
                filterPhasesCurves[filterIndex].append(GraphPoint(result: phase, frequency: frequency))
            }
            totalPhaseCurve.append(GraphPoint(result: totalPhase, frequency: frequency))
        }
        return GraphData(filterCurves: filterPhasesCurves, totalCurve: totalPhaseCurve)
    }

    private func generateUnwrappedPhaseGraph(frequencies: [Double]) -> GraphData {
        let phaseData = generatePhaseGraph(frequencies: frequencies)
        let filterData = phaseData.filterCurves
		var unwrappedPhaseData = [GraphCurve] ()

        filterData.forEach { curve in
            var newCurve = [curve[0]]
            for pointIndex in 1 ..< curve.count {
                var result = curve[pointIndex].result
                while ((result - curve[pointIndex - 1].result) <= -170.0) {
                    result = result + 360
                }
                while ((result - curve[pointIndex - 1].result) >= 170) {
                    result = result - 360
                }
                newCurve.append(GraphPoint(result: result, frequency: curve[pointIndex].frequency))
            }
            unwrappedPhaseData.append(newCurve)
        }
        return GraphData(filterCurves: unwrappedPhaseData, totalCurve: phaseData.totalCurve)
    }

    func generateGroupDelayGraph(frequencies: [Double]) -> GraphData {
        let phaseData = generateUnwrappedPhaseGraph(frequencies: frequencies)
        let filterPhaseData = phaseData.filterCurves

        let totalGroupDelayCurve = GraphCurve()
        var filterDelayCurves = filters.map({ _ in
            return GraphCurve()
        })

        for filterIndex in 0 ..< filterPhaseData.count {
            let phaseCurve = filterPhaseData[filterIndex]

            var newResult = -1000.0 * (((phaseCurve[1].result - phaseCurve[0].result) / (phaseCurve[1].frequency - phaseCurve[0].frequency)) / 360.0);
            filterDelayCurves[filterIndex].append(GraphPoint(result: newResult, frequency: phaseCurve[0].frequency))
            for f in 1 ..< phaseCurve.count {
                let ratio = (phaseCurve[f].result - phaseCurve[f - 1].result) / (phaseCurve[f].frequency - phaseCurve[f - 1].frequency)
                newResult = -1000.0 * (ratio / 360.0)
                filterDelayCurves[filterIndex].append(GraphPoint(result: newResult, frequency: phaseCurve[f].frequency))
            }
        }

        return GraphData(filterCurves: filterDelayCurves, totalCurve: totalGroupDelayCurve)
    }
}
