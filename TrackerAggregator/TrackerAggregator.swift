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

    init() {}

    private var wasConfigured: Bool = false {
        didSet {
            if wasConfigured {
                DispatchQueue.global().async {
                    self.postponedEvents.forEach { self.trackEvent(event: $0) }
                    self.postponedEvents.removeAll()
                    self.postponedProperties.forEach { self.update(property: $0) }
                    self.postponedProperties.removeAll()
                }
            }
        }
    }

    private var postponedEvents: [TrackableEvent] = []
    private var postponedProperties: [TrackableProperty] = []

    private var trackers: [Tracker] = []

    func set(trackers: [Tracker]) {
        self.trackers = trackers
    }

    func configureTrackers() {
        DispatchQueue.global().async {
            self.trackers.forEach { $0.configure() }
            self.wasConfigured = true
        }
    }

    func trackEvent(event: TrackableEvent) {

        if !wasConfigured {
            postponedEvents.append(event)
            // Should reschedule to be sent after configuration is complete
            return
        }

        DispatchQueue.global().async {
            self._trackEvent(event: event)
        }
    }

    private func _trackEvent(event: TrackableEvent) {

        trackers.forEach { tracker in

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

    func update(property: TrackableProperty) {

        if !wasConfigured {
            postponedProperties.append(property)
            return
        }

        DispatchQueue.global().async {
            self._update(property: property)
        }
    }

    private func _update(property: TrackableProperty) {
        trackers.forEach { tracker in
            let action = {
                tracker.track(property: property)
                property.generateUpdateEvents().forEach(self._trackEvent)
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

    // MARK: - Public API

    /// Plug in trackers
    class func set(trackers: [Tracker]) {
        shared.set(trackers: trackers)
    }

    /// Configure trackers, must be called to be able to track. Event or Property track attepts prior configure are postponed.
    class func configureTrackers() {
        shared.configureTrackers()
    }

    /// Track event
    class func trackEvent(event: TrackableEvent) {
        shared.trackEvent(event: event)
    }

    /// Update property
    class func update(property: TrackableProperty) {
        shared.update(property: property)
    }
}
