# Tracker Aggregator
Bundle of protocols to keep your analytics clean and simple

# Why?
In case you use multiple analytic tools like Mixpanel, Intercom, Segment, Fabric (you name it…), you probably have the tracking code all over your project. Tracker-Aggregator is a simple interface for your project analytics that allows you to simply plug-in third party tools. This mechanism also allows you to easily migrate from one analytics tool to another.

# Installation
Just copy `TrackerAggregator.swift` to your project

# How it works?
Tracker aggregator supports two ways of tracking things - events and properties.

## Plug-in analytics tool

Let's say we want to use Mixpanel and Intercom for tracking. We create simple classes that encapsulate them and conform them to Tracker protocol. 

```swift
// Intercom tracker definition

class IntercomTracker: Tracker {

    var eventTrackingRule: EventTrackingRule? = nil
    var propertyTrackingRule: PropertyTrackingRule? = nil

    func track(event: TrackableEvent) {
        // Custom Intercom logic for how to track events
        Intercom.logEvent(withName: event.identifier, metaData: event.metadata)
    }

    func track(property: TrackableProperty) {
        // Custom Intercom logic for how to track properties
        let attributes = ICMUserAttributes()
        attributes.customAttributes = [property.identifier: property.trackedValue]
        Intercom.updateUser(attributes)
    }
}

// Mixpanel Tracker definition

class MixpanelTracker: Tracker {

    var eventTrackingRule: EventTrackingRule? = nil
    var propertyTrackingRule: PropertyTrackingRule? = nil

    func track(event: TrackableEvent) {
        // Custom Mixpanel logic for how to track events
    }

    func track(property: TrackableProperty) {
        // Custom Mixpanel logic for how to track properties
    }
}
```

In your AppDelegate, for example, you can now plug-in your trackers.

```swift
GlobalTracker.set(trackers: [IntercomTracker(), MixpanelTracker()])
```

## Track events

First, we define event we want to track. To do so need struct that conforms to `TrackableEvent` protocol. 

```swift
struct AppOpen: TrackableEvent {
    let identifier: String = "App: Open"      // Name of the event 
    let metadata: [String : Any] = [:]        // Any metadata we need to pass with it 
}
```

We defined our first event. Now we track it with `GlobalTracker` ( an interface that forwards the event to all plugged trackers).

```swift
let appOpen = AppOpen()
GlobalTracker.track(event: appOpen)
```

## Track property

Similarly to event tracking, we define a struct that represents our property by conforming it to `TrackableProperty` protocol

```swift
struct Email: TrackableProperty {
    let identifier: String = "email"                          // Name of the property
    let value: String                                         // Our value, whatever type we need

    var trackedValue: TrackableValueType { return value }     // How to convert our value to TrackableValueType
                                                              // String and Int are trackable by default
}
```

and now we track it 

```swift
let email = Email(value: "test@test.com")
GlobalTracker.update(property: email)
```

# Notes
This micro framework is still under development and therefore might change in a future.

