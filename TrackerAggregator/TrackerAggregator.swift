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

protocol TrackerConfigurable: class {
    /// This is called before anything is tracked to configure each tracker. This is being called on background thread!
    func configure()

    var name: String { get }
}

extension TrackerConfigurable {
    var name: String {
        return String(describing: type(of: self))
    }
}

protocol AnalyticsAdapter: EventTrackable, PropertyTrackable, TrackerConfigurable {}

struct EventIdentifier {
    let object: String
    let action: String
    let label: String?

    init(object: String, action: String, label: String? = nil) {
        self.object = object
        self.action = action
        self.label = label
    }

    var formatted: String {
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
extension Double: TrackableValueType {}

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

    private let trackingQueue = DispatchQueue(label: "com.global-tracker.tracking-queue", qos: DispatchQoS.background, attributes: .concurrent)

    init() {}

    private var wasConfigured: Bool = false {
        didSet {
            if wasConfigured {
                trackingQueue.async {
                    self.postponedEvents.forEach { self.track(event: $0) }
                    self.postponedEvents.removeAll()
                    self.postponedProperties.forEach { self.update(property: $0) }
                    self.postponedProperties.removeAll()
                }
            }
        }
    }

    var postponedEvents: [TrackableEvent] = []
    var postponedProperties: [TrackableProperty] = []
    private var adapters: [AnalyticsAdapter] = []
    var loggingEnabled: Bool = false

    func set(adapters: [AnalyticsAdapter]) {
        self.adapters = adapters
    }

    func configureAdapters() {
        trackingQueue.async {
            self.adapters.forEach { $0.configure() }
            self.wasConfigured = true
        }
    }

    func track(event: TrackableEvent) {

        if !wasConfigured {
            postponedEvents.append(event)
            // Should reschedule to be sent after configuration is complete
            return
        }

        trackingQueue.async {
            self._track(event: event)
        }
    }

    private func _track(event: TrackableEvent) {

        func trackEvent(event: TrackableEvent, tracker: AnalyticsAdapter) {
            if self.loggingEnabled {
                print("-[\(tracker.name)]: EVENT TRIGGERED - '\(event.identifier.formatted)'")
            }

            tracker.track(event: event)
        }

        adapters.forEach { tracker in
            if let rule = tracker.eventTrackingRule {
                let isIncluded = rule.types.contains(where: { type(of: event) == $0 })

                if isIncluded && rule.rule == .allow {
                    trackEvent(event: event, tracker: tracker)
                } else if !isIncluded && rule.rule == .prohibit {
                    trackEvent(event: event, tracker: tracker)
                }
            } else {
                trackEvent(event: event, tracker: tracker)
            }
        }
    }

    func update(property: TrackableProperty) {

        if !wasConfigured {
            postponedProperties.append(property)
            return
        }

        trackingQueue.async {
            self._update(property: property)
        }
    }

    private func _update(property: TrackableProperty) {
        adapters.forEach { tracker in
            let action = {
                tracker.track(property: property)

                if self.loggingEnabled {
                    print("-[\(tracker.name)]: '\(property.identifier)' UPDATED TO '\(property.trackedValue)'")
                }

                property.generateUpdateEvents().forEach(self._track)
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
    class func set(adapters: [AnalyticsAdapter]) {
        shared.set(adapters: adapters)
    }

    /// Configure trackers, must be called to be able to track. Event or Property track attepts prior configure are postponed.
    class func configureAdapters() {
        shared.configureAdapters()
    }

    /// Track event
    class func track(event: TrackableEvent) {
        shared.track(event: event)
    }

    /// Update property
    class func update(property: TrackableProperty) {
        shared.update(property: property)
    }

    /// Default False
    class var loggingEnabled: Bool {
        set {
            shared.loggingEnabled = newValue
        }
        get {
            return shared.loggingEnabled
        }
    }
}

// Event triggering shortcut
extension TrackableEvent {
    func trigger() {
        GlobalTracker.track(event: self)
    }
}

// Property update shortcut
extension TrackableProperty {
    func update() {
        GlobalTracker.update(property: self)
    }
}
