import Foundation

// Shipment stages (21 Oct 2026 review). A shipment is a list of stages; each records a location, start and
// end times, the estimate it was planned against, a status and an optional delay reason. The API
// (shipments/show.php) returns them next to the shipment; the list endpoint returns only `currentStage`.

enum LimuDuration {
    /// "2d 4h", "3h 20m", "45m". Nil when the duration is unknown.
    static func text(minutes: Int?) -> String {
        guard let minutes else { return "—" }
        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        let mins = minutes % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if mins > 0 || parts.isEmpty { parts.append("\(mins)m") }
        return parts.prefix(2).joined(separator: " ")
    }
}

struct ShipmentStageSnippet: Hashable {
    let name: String
    let status: String
    let location: String
    let startAt: String?
    let estimatedCompletion: String?
    let elapsedMinutes: Int?
    let estimatedMinutes: Int?
    let varianceMinutes: Int?
    let index: Int
    let count: Int
    let progress: Double

    /// "2d 4h ahead of estimate" / "3h over estimate" / nil when there is nothing to compare.
    var comparison: String? {
        guard let varianceMinutes, estimatedMinutes != nil else { return nil }
        if varianceMinutes == 0 { return "On the estimate" }
        let amount = LimuDuration.text(minutes: abs(varianceMinutes))
        return varianceMinutes < 0 ? "\(amount) ahead of estimate" : "\(amount) over estimate"
    }
}

struct ShipmentStage: Identifiable, Hashable {
    let id: Int
    let position: Int
    let name: String
    let location: String
    let isOptional: Bool
    let status: String
    let startAt: String?
    let estimatedEndAt: String?
    let endAt: String?
    let durationMinutes: Int?
    let delayReason: String?

    var isCompleted: Bool { status.caseInsensitiveCompare("Completed") == .orderedSame }
    var isCurrent: Bool {
        ["in progress", "delayed"].contains(status.lowercased())
    }
}

struct ShipmentStageUpdate: Identifiable, Hashable {
    let id: Int
    let stage: String
    let status: String
    let location: String
    let message: String
    let timestamp: String

    init(id: Int, stage: String, status: String, location: String, message: String, timestamp: String) {
        self.id = id
        self.stage = stage
        self.status = status
        self.location = location
        self.message = message
        self.timestamp = LimuDateFormatting.display(timestamp)
    }
}

struct ShipmentPlan: Hashable {
    let route: String
    let origin: String
    let destination: String
    let estLoadingDate: String?
    let estArrivalDate: String?
    let estCollectionDate: String?
    let estTransitDays: Int?
}

struct ShipmentHistoryRow: Identifiable, Hashable {
    var id: String { stage }
    let stage: String
    let samples: Int
    let averageMinutes: Int
    let averageEstimatedMinutes: Int?
}

/// What previous shipments of the same mode took, so a client can estimate the next one.
struct ShipmentHistory: Hashable {
    let stages: [ShipmentHistoryRow]
    let estimateAccuracy: Double?
    let estimateSamples: Int
}

struct CargoChecklistStep: Identifiable, Hashable {
    let id: String
    let title: String
    let done: Bool
    let timestamp: String?
    let detail: String?
}

// MARK: - API payloads

struct ShipmentStageSnippetDTO: Decodable {
    let name: String
    let status: String
    let location: String
    let startAt: String?
    let estimatedCompletion: String?
    let elapsedMinutes: Int?
    let estimatedMinutes: Int?
    let varianceMinutes: Int?
    let stageIndex: Int
    let stageCount: Int
    let progress: Double

    var model: ShipmentStageSnippet {
        ShipmentStageSnippet(
            name: name, status: status, location: location, startAt: startAt,
            estimatedCompletion: estimatedCompletion, elapsedMinutes: elapsedMinutes,
            estimatedMinutes: estimatedMinutes, varianceMinutes: varianceMinutes,
            index: stageIndex, count: stageCount, progress: progress
        )
    }
}

struct ShipmentStageDTO: Decodable {
    let id: Int
    let position: Int
    let name: String
    let location: String
    let isOptionalStage: Bool?
    let status: String
    let startAt: String?
    let estimatedEndAt: String?
    let endAt: String?
    let durationMinutes: Int?
    let delayReason: String?

    private enum CodingKeys: String, CodingKey {
        case id, position, name, location, status, startAt, estimatedEndAt, endAt, durationMinutes, delayReason
        case isOptionalStage = "optional"
    }

    var model: ShipmentStage {
        ShipmentStage(
            id: id, position: position, name: name, location: location, isOptional: isOptionalStage ?? false,
            status: status, startAt: startAt, estimatedEndAt: estimatedEndAt, endAt: endAt,
            durationMinutes: durationMinutes, delayReason: delayReason
        )
    }
}

struct ShipmentStageUpdateDTO: Decodable {
    let id: Int
    let stage: String
    let status: String
    let location: String
    let message: String
    let timestamp: String?

    var model: ShipmentStageUpdate {
        ShipmentStageUpdate(id: id, stage: stage, status: status, location: location, message: message, timestamp: timestamp ?? "—")
    }
}

struct ShipmentPlanDTO: Decodable {
    let route: String?
    let origin: String?
    let destination: String?
    let estLoadingDate: String?
    let estArrivalDate: String?
    let estCollectionDate: String?
    let estTransitDays: Int?

    var model: ShipmentPlan {
        ShipmentPlan(
            route: route ?? "", origin: origin ?? "", destination: destination ?? "",
            estLoadingDate: estLoadingDate, estArrivalDate: estArrivalDate,
            estCollectionDate: estCollectionDate, estTransitDays: estTransitDays
        )
    }
}

struct ShipmentHistoryDTO: Decodable {
    struct Row: Decodable {
        let stage: String
        let samples: Int
        let averageMinutes: Int
        let averageEstimatedMinutes: Int?
    }

    let stages: [Row]
    let estimateAccuracy: Double?
    let estimateSamples: Int

    var model: ShipmentHistory {
        ShipmentHistory(
            stages: stages.map {
                ShipmentHistoryRow(stage: $0.stage, samples: $0.samples, averageMinutes: $0.averageMinutes, averageEstimatedMinutes: $0.averageEstimatedMinutes)
            },
            estimateAccuracy: estimateAccuracy,
            estimateSamples: estimateSamples
        )
    }
}

struct CargoReferenceDTO: Decodable {
    let id: Int
    let trackingNumber: String
}

struct CargoChecklistStepDTO: Decodable {
    let key: String
    let title: String
    let done: Bool
    let timestamp: String?
    let detail: String?

    var model: CargoChecklistStep {
        CargoChecklistStep(id: key, title: title, done: done, timestamp: timestamp.map { LimuDateFormatting.display($0) }, detail: detail)
    }
}

// MARK: - Analytics (Overview card)

/// One entry per stage: on time, late, done with no estimate to compare, in progress, or not started.
enum StageOutcome: Hashable {
    case onTime, late, done, current, open
}

struct ShipmentAnalytics: Hashable {
    let totalStages: Int
    let stagesOnTime: Int
    let stagesLate: Int
    let averageVarianceMinutes: Int?
    let actualMinutes: Int?
    let expectedMinutes: Int?
    let expectedProgress: Double?
    let projectedArrival: String?
    let plannedArrival: String?
    let delayedStages: [(name: String, reason: String)]
    let stageOutcomes: [StageOutcome]

    static func == (lhs: ShipmentAnalytics, rhs: ShipmentAnalytics) -> Bool {
        lhs.totalStages == rhs.totalStages && lhs.stageOutcomes == rhs.stageOutcomes && lhs.stagesLate == rhs.stagesLate
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(totalStages)
        hasher.combine(stageOutcomes)
    }
}

enum ShipmentAnalyticsCalculator {
    private static let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]

    static func parse(_ value: String?) -> Date? {
        guard let text = value?.trimmingCharacters(in: .whitespaces), !text.isEmpty, !text.hasPrefix("0000") else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    static func calculate(_ shipment: Shipment, now: Date = Date()) -> ShipmentAnalytics {
        let stages = shipment.stages
        let completed = stages.filter(\.isCompleted)
        let variances: [Double] = completed.compactMap { stage in
            guard let est = parse(stage.estimatedEndAt), let end = parse(stage.endAt) else { return nil }
            return end.timeIntervalSince(est) / 60
        }
        let firstStart = stages.first { $0.startAt != nil }.flatMap { parse($0.startAt) }
        let plannedStart = parse(shipment.plan?.estLoadingDate)
        let plannedArrival = parse(shipment.plan?.estArrivalDate)
        let allDone = !stages.isEmpty && stages.allSatisfy(\.isCompleted)
        let lastEnd = allDone ? parse(stages.last?.endAt) : nil

        let actualMinutes = firstStart.map { Int((((lastEnd ?? now).timeIntervalSince($0)) / 60).rounded()) }
        let expectedMinutes = (plannedStart != nil && plannedArrival != nil)
            ? Int((plannedArrival!.timeIntervalSince(plannedStart!) / 60).rounded()) : nil

        // Nothing is expected before the planned loading date, so there is no expected figure rather than 0%.
        var expectedProgress: Double? = nil
        if let start = plannedStart, let arrival = plannedArrival, now >= start, arrival > start {
            expectedProgress = min(max(now.timeIntervalSince(start) / arrival.timeIntervalSince(start), 0), 1)
        }

        // Projected arrival: the planned arrival moved by the average stage variance so far.
        var projectedArrival: String? = nil
        if let arrival = plannedArrival {
            let average = variances.isEmpty ? 0 : variances.reduce(0, +) / Double(variances.count)
            let projected = arrival.addingTimeInterval(average * 60)
            let day = DateFormatter()
            day.dateFormat = "yyyy-MM-dd"
            projectedArrival = day.string(from: projected)
        }

        let average: Int? = variances.isEmpty ? nil : Int((variances.reduce(0, +) / Double(variances.count)).rounded())

        let outcomes: [StageOutcome] = stages.map { stage in
            let est = parse(stage.estimatedEndAt)
            let end = parse(stage.endAt)
            if stage.isCompleted {
                guard let est, let end else { return .done }
                return end > est ? .late : .onTime
            }
            return stage.isCurrent ? .current : .open
        }

        return ShipmentAnalytics(
            totalStages: stages.count,
            stagesOnTime: outcomes.filter { $0 == .onTime }.count,
            stagesLate: outcomes.filter { $0 == .late }.count,
            averageVarianceMinutes: average,
            actualMinutes: actualMinutes,
            expectedMinutes: expectedMinutes,
            expectedProgress: expectedProgress,
            projectedArrival: projectedArrival,
            plannedArrival: shipment.plan?.estArrivalDate,
            delayedStages: stages.compactMap { stage in
                guard let reason = stage.delayReason, !reason.isEmpty else { return nil }
                return (name: stage.name, reason: reason)
            },
            stageOutcomes: outcomes
        )
    }
}
