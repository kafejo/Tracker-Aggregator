<img src="https://github.com/kafejo/Tracker-Aggregator/blob/master/Assets/logo-text@2x.png" width="302" />

An abstraction layer for analytics in your app.

<img src="https://github.com/kafejo/Tracker-Aggregator/blob/master/Assets/graph.png"/>

# Why?
In case you use multiple analytic tools like Mixpanel, Intercom, Segment, Fabric (you name it…), you probably have the tracking code all over your project. Tracker-Aggregator is a simple interface for your project analytics that allows you to simply plug-in third party tools. This mechanism also allows you to easily migrate from one analytics tool to another.

## Features
#### 👉 Support both Events and Properties
Many tracking tools are able to track events as well as properties (usually called User properties or User attributes). 

#### 🕺 Easily plug-in new analytics of your choice
Adding new analytic tool is a matter of implementing three simple methods.

#### 🏃 Asynchronous
Startup time matters. Everything is dispatched to the background, even first setup, and it's up to you when you call it. Every event or property update called before everything is ready is saved in a queue and triggered once the configuration is done.

#### ✍️ Configurable
You can define what you want to track for each analytics by setting rules. By default, everything is tracked. You can easily allow only certain events to be tracked for your AnalyticsTool1 and at the same time prohibit few events from the whole to be tracked by your AnalyticsTool2.

#### 👮 Conventional
Event and property names are important for the data analytic to easily understand what they mean. Tracker Aggregator is using convention of _Object: Action - Label_ where label is optional. That way you group your events into logical categories. 
Examples:
* App: Opened
* App: Closed
* Song: Tapped - More Info
* Artist: Viewed 


# How does it work?
Define your events and properties by creating structs and conforming them to TrackableEvent or TrackableProperty. Setup your analytic adapters and plug them into _GlobalTracker_ (acts as a hub that forwards events and properies to plugged adapters). 

## Define events

To do so you need a struct that conforms to `TrackableEvent` protocol. 

```swift
struct AppOpen: TrackableEvent {
    let identifier: EventIdentifier = EventIdentifier(object: "App", action: "Open")      // Name of the event 
    let metadata: [String : Any] = [:]        // Any metadata we need to pass with the event 
}
```

In case we want to add a metadata to an event, we simply add new property to the struct and adjust the metadata getter.

```swift
struct AppOpen: TrackableEvent {
    let timestamp: Date
    
    let identifier: EventIdentifier = EventIdentifier(object: "App", action: "Open")
    var metadata: [String : Any] { 
        return ["timestamp": dateFormatter.string(from: timestamp)] 
    }
}
```

Now, to track our `AppOpen` event, we just need to initialize it and call `trigger()`.

```swift
AppOpen(timestamp: Date()).trigger()
```

Trigger method just simply calls the event on `GlobalTracker` that forwards it to all plugged analytics adapters if they support it.

## Track property

Similarly to event tracking, we define a struct that represents our property by conforming it to `TrackableProperty` protocol

```swift
struct Email: TrackableProperty {
    let identifier: String = "email"                          // Name of the property
    let value: String                                         // Our value, whatever type we need. Enums are handy.

    var trackedValue: TrackableValueType { return value }     // How to convert our value to TrackableValueType
                                                              // String and Int are trackable by defaul
}
```

and now we track it by calling update on it.

```swift
Email(value: "test@test.com").update()
```

## Plug-in analytics tool

We create simple classes that encapsulate each analytic tool login by conforming them to `AnalyticsAdapter` protocol. 

```swift
import Mixpanel

class MixpanelAdapter: AnalyticsAdapter {

    private let token: String

    init(token: String) {
        self.token = token
    }
 
    func configure() {
        _ = Mixpanel.sharedInstance(withToken: token)
    }

    func track(event: TrackableEvent) {
        // Track event in Mixpanel
        Mixpanel.sharedInstance()?.track(event.identifier.stringValue, properties: event.metadata)
    }

    func track(property: TrackableProperty) {
        // Track property in Mixpanel
        Mixpanel.sharedInstance()?.people.set(property.identifier, to: property.trackedValue)
    }
}
```

In your AppDelegate, for example, you can now plug-in your adapters to `GlobalTracker` and call `configureAdapters()`.

```swift
GlobalTracker.set(adapters: [MixpanelAdapter(token: "abcd")])
GlobalTracker.configureAdapters()
```

## Rules
You may want to allow only certain events or properties to be tracker by specific trackers. To do so, each tracker can specify `EventTrackingRule` and `PropertyTrackingRule`. In the rule you have to define either only allowed events/properties or prohibit only certain events/properties. Let's prohibit `Mixpanel` to track `AppOpen` event.

```swift
class MixpanelAdapter: AnalyticsAdapter {
    
    // Set event tracking rule to prohibit AppOpen event from being tracked
    // That means function track(event:) for this tracker wont be called for AppOpen event
    let eventTrackingRule: EventTrackingRule? = EventTrackingRule(.prohibit, types: [AppOpen.self])

    private let token: String

    init(token: String) {
        self.token = token
    }

    func configure() {
        _ = Mixpanel.sharedInstance(withToken: token)
    }

    func track(event: TrackableEvent) {
        // Track event in Mixpanel
        Mixpanel.sharedInstance()?.track(event.identifier.stringValue, properties: event.metadata)
    }

    func track(property: TrackableProperty) {
        // Track property in Mixpanel
        Mixpanel.sharedInstance()?.people.set(property.identifier, to: property.trackedValue)
    }
}
```

You can also use `.allow` rule to allow only certain events. The same mechanism works for properies, just define `propertyTrackingRule` in your adapter.

# Installation
Just copy `TrackerAggregator.swift` to your project. Tracker Aggregator is so small (just one file) that it's not worth to use it as a linked framework.

# License
Tracker Aggregator is under MIT license. See the LICENSE file for more info.
