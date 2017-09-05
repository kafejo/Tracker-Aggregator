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

extension PropertyTrackable {
    var propertyTrackingRule: PropertyTrackingRule? {
        return nil
    }
}

extension EventTrackable {
    var eventTrackingRule: EventTrackingRule? {
        return nil
    }
}

protocol TrackerConfigurable {
    /// This is called before anything is tracked to configure each tracker. This is being called on background thread!
    func configure()
}

protocol Tracker: EventTrackable, PropertyTrackable, TrackerConfigurable {}

struct EventIdentifier {
    let object: String
    let action: String
    let label: String?

    init(object: String, action: String, label: String? = nil) {
        self.object = object
        self.action = action
        self.label = label
    }

    var stringValue: String {
        if let label = label {
            return "\(object): \(action) - \(label)"
        } else {
            return "\(object): \(action)"
        }
    }
}

// MARK: - Event tracking

protocol EventIdentifiable {
    var identifier: EventIdentifier { get }
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
extension Bool: TrackableValueType {}
extension Int: TrackableValueType {}

protocol TrackableProperty {
    var identifier: String { get }
    var trackedValue: TrackableValueType { get }

    func generateUpdateEvents() -> [TrackableEvent]
}

extension TrackableProperty {
    func generateUpdateEvents() -> [TrackableEvent] {
        return []
    }
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

    class func configureTrackers() {
        DispatchQueue.global().async {
            shared.trackers.forEach { $0.configure() }
        }
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
            let action = {
                tracker.track(property: property)
                property.generateUpdateEvents().forEach(trackEvent)
            }

            if let rule = tracker.propertyTrackingRule {
                let isIncluded = rule.types.contains(where: { type(of: property) == $0 })

                if isIncluded && rule.rule == .allow {
                    action()
                } else if !isIncluded && rule.rule == .prohibit {
                    action()
                }
            } else {
                action()
            }
        }
    }
}
