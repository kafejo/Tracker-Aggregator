//
//  TrackerAggregator.swift
//  TrackerAggregator
//
//  Created by Ales Kocur on 25/08/2017.
//  Copyright © 2017 All rights reserved.
//

import Foundation

// MARK: - Tracking types

protocol TrackerConfigurable: AnyObject {
    /// This is called before anything is tracked to configure each tracker. This is being called on background thread!
    func configure()
    func reset()

    var name: String { get }
}

extension TrackerConfigurable {
    var name: String {
        return String(describing: type(of: self))
    }

    func reset() {}
}

protocol AnalyticsAdapter: EventTrackable, PropertyTrackable, TrackerConfigurable {}

extension AnalyticsAdapter {
    func shouldTrackEvent(_ event: TrackableEvent) -> Bool {
        
        guard let rule = eventTrackingRule else {
            return true
        }
        
        let isIncluded = rule.types.contains(where: { type(of: event) == $0 })

        if (isIncluded && rule.rule == .allow) || (!isIncluded && rule.rule == .prohibit) {
            return true
        } else {
            return false
        }
    }
}

// MARK: - Global Tracker

class GlobalTracker {

    private static let shared = GlobalTracker()

    private let trackingQueue = DispatchQueue(label: "com.global-tracker.tracking-queue", qos: DispatchQoS.background, attributes: .concurrent)

    init() {}

    private var wasConfigured: Bool = false

    var postponedEvents: [TrackableEvent] = []
    var postponedProperties: [TrackableProperty] = []
    private var adapters: [AnalyticsAdapter] = []

    private var log: ((String) -> Void) = { message in
        print(message)
    }
    
    enum LoggingLevel {
        case none, info, verbose
    }
    
    var loggingLevel: LoggingLevel = .none

    func set(adapters: [AnalyticsAdapter]) {
        self.adapters = adapters
    }

    func configureAdapters() {
        trackingQueue.sync {
            self.adapters.forEach { $0.configure() }
            self.wasConfigured = true
            self.postponedEvents.forEach { self.track(event: $0) }
            self.postponedProperties.forEach { self.update(property: $0) }
            self.postponedEvents.removeAll()
            self.postponedProperties.removeAll()
        }
    }

    func resetAdapters() {
        trackingQueue.sync {
            self.adapters.forEach { $0.reset() }
        }
    }

    func track(event: TrackableEvent) {

        if !self.wasConfigured {
            self.postponedEvents.append(event)
            // Should reschedule to be sent after configuration is complete
            return
        }

        trackingQueue.sync {
            self._track(event: event)
        }
    }

    private func _track(event: TrackableEvent) {
        func trackEvent(event: TrackableEvent, tracker: AnalyticsAdapter) {
            if self.loggingLevel == .info {
                log("-[\(tracker.name)]: EVENT TRIGGERED - '\(event.identifier.formatted)'")
            } else if self.loggingLevel == .verbose {
                if event.metadata.count > 0 {
                    let metadata = event.metadata.compactMap { "\($0.key): \($0.value)"}.joined(separator: "\n > ")
                    log("-[\(tracker.name)]: EVENT TRIGGERED - '\(event.identifier.formatted)' \n > \(metadata)")
                } else {
                    log("-[\(tracker.name)]: EVENT TRIGGERED - '\(event.identifier.formatted)' (no meta)")
                }
                
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

        if !self.wasConfigured {
            trackingQueue.async(flags: .barrier) {
                self.postponedProperties.append(property)
            }
            return
        }

        trackingQueue.sync {
            self._update(property: property)
        }
    }

    private func _update(property: TrackableProperty) {

        self.adapters.forEach { tracker in
            let action = {
                tracker.track(property: property)

                if self.loggingLevel == .info {
                    self.log("-[\(tracker.name)]: '\(property.identifier)' UPDATED TO '\(property.trackedValue ?? "nil")'")
                }
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

        property.generateUpdateEvents().forEach(self._track)
    }
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        
        return formatter
    }()

    // MARK: - Public API

    /// Set adapters to track events to and configure them to start tracking
    class func startTracking(adapters: [AnalyticsAdapter]) {
        shared.set(adapters: adapters)
        shared.configureAdapters()
    }

    class func log(logClosure: @escaping (String) -> Void) {
        shared.log = logClosure
    }

    /// Reset trackers so them set new unregistered user
    class func resetAdapters() {
        shared.resetAdapters()
    }

    /// Track event
    class func track(event: TrackableEvent) {
        shared.track(event: event)
    }

    /// Update property
    class func update(property: TrackableProperty) {
        shared.update(property: property)
    }

    /// Default `.none`
    class var loggingLevel: LoggingLevel {
        get {
            return shared.loggingLevel
        }
        set {
            shared.loggingLevel = newValue
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

extension EventIdentifier {
    func underscoredLowercased() -> String {
        if let label = label {
            return "\(object)_\(action)_\(label)".lowercased().replacingOccurrences(of: " ", with: "_")
        } else {
            return "\(object)_\(action)".lowercased().replacingOccurrences(of: " ", with: "_")
        }
    }
}

enum TrackingRule {
    case allow, prohibit
}

// MARK: - Event tracking

protocol EventTrackable {
    var eventTrackingRule: EventTrackingRule? { get }

    func track(event: TrackableEvent)
}

extension EventTrackable {
    var eventTrackingRule: EventTrackingRule? {
        return nil
    }
}

protocol EventIdentifiable {
    var identifier: EventIdentifier { get }
}

protocol MetadataConvertible {
    var metadata: [String: Any] { get }
}

extension MetadataConvertible {
    var metadata: [String: Any] {
        [:]
    }
}

protocol TrackableEvent: MetadataConvertible, EventIdentifiable {}

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
    var trackedValue: TrackableValueType? { get }

    func generateUpdateEvents() -> [TrackableEvent]
}

extension TrackableProperty {
    func generateUpdateEvents() -> [TrackableEvent] {
        return []
    }
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

struct PropertyTrackingRule {
    let rule: TrackingRule
    let types: [TrackableProperty.Type]

    init(_ rule: TrackingRule, types: [TrackableProperty.Type]) {
        self.rule = rule
        self.types = types
    }
}

extension TrackableValueType {
    var stringValue: String {
        switch self {
        case let string as String:
            return string
        case let int as Int:
            return String(int)
        case let bool as Bool:
            return bool ? "true" : "false"
        case let double as Double:
            return String(double)
        default:
            return "unsupported_value"
        }
    }
}

