//
//  TrackerAggregator.swift
//  TrackerAggregator
//
//  Created by Ales Kocur on 25/08/2017.
//  Copyright © 2017 Rubicoin Ltd. All rights reserved.
//

import Foundation


enum TrackingRule {
    case allow, prohibit
}

// MARK: - Tracking types

protocol EventTrackable {
    var eventTrackingRule: EventTrackingRule? { get }

    func track(event: TrackableEvent)
}

protocol PropertyTrackable {
    var propertyTrackingRule: PropertyTrackingRule? { get }

    func track(property: TrackableProperty)
}

protocol Tracker: EventTrackable, PropertyTrackable {}

// MARK: - Event tracking

protocol EventIdentifiable {
    var identifier: String { get }
}

protocol MetadataConvertible {
    var metadata: [String: Any] { get }
}

protocol TrackableEvent: MetadataConvertible, EventIdentifiable {}

struct EventTrackingRule {
    let rule: TrackingRule
    let types: [TrackableEvent.Type]

    init(_ rule: TrackingRule, types: [TrackableEvent.Type]) {
        self.rule = rule
        self.types = types
    }
}

// MARK: - Property tracking

protocol TrackableValueType { }

extension String: TrackableValueType {}

extension Int: TrackableValueType {}

protocol TrackableProperty {
    var key: String { get }
    var trackedValue: TrackableValueType { get }

    func generateUpdateEvents() -> [TrackableEvent]
}

struct PropertyTrackingRule {
    let rule: TrackingRule
    let types: [TrackableProperty.Type]

    init(_ rule: TrackingRule, types: [TrackableProperty.Type]) {
        self.rule = rule
        self.types = types
    }
}

// MARK: - Global Tracker

class GlobalTracker {

    private static let shared = GlobalTracker()

    private init() {}

    var trackers: [Tracker] = []

    class func set(trackers: [Tracker]) {
        shared.trackers = trackers
    }

    class func trackEvent(event: TrackableEvent) {
        shared.trackers.forEach { tracker in

            if let rule = tracker.eventTrackingRule {
                let isIncluded = rule.types.contains(where: { type(of: event) == $0 })

                if isIncluded && rule.rule == .allow {
                    tracker.track(event: event)
                } else if !isIncluded && rule.rule == .prohibit {
                    tracker.track(event: event)
                }
            } else {
                tracker.track(event: event)
            }
        }
    }

    class func update(property: TrackableProperty) {
        shared.trackers.forEach { tracker in
            if let rule = tracker.propertyTrackingRule {
                let isIncluded = rule.types.contains(where: { type(of: property) == $0 })

                if isIncluded && rule.rule == .allow {
                    tracker.track(property: property)
                } else if !isIncluded && rule.rule == .prohibit {
                    tracker.track(property: property)
                }
            } else {
                tracker.track(property: property)
            }
        }
    }
}
