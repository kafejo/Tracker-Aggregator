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

protocol UserPropertyTrackable {
    var propertyTrackingRule: UserPropertyTrackingRule? { get }

    func track(userProperty: TrackableUserProperty)
}

protocol Tracker: EventTrackable, UserPropertyTrackable {}

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

// MARK: - User Property tracking

protocol TrackableValueType { }

extension String: TrackableValueType {}

extension Int: TrackableValueType {}

protocol TrackableUserProperty {
    var key: String { get }
    var trackedValue: TrackableValueType { get }

    func generateUpdateEvents() -> [TrackableEvent]
}

struct UserPropertyTrackingRule {
    let rule: TrackingRule
    let types: [TrackableUserProperty.Type]

    init(_ rule: TrackingRule, types: [TrackableUserProperty.Type]) {
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

    class func update(property: TrackableUserProperty) {
        shared.trackers.forEach { tracker in
            if let rule = tracker.propertyTrackingRule {
                let isIncluded = rule.types.contains(where: { type(of: property) == $0 })

                if isIncluded && rule.rule == .allow {
                    tracker.track(userProperty: property)
                } else if !isIncluded && rule.rule == .prohibit {
                    tracker.track(userProperty: property)
                }
            } else {
                tracker.track(userProperty: property)
            }
        }
    }
}
