<img src="https://github.com/kafejo/Tracker-Aggregator/blob/master/Assets/logo-text@2x.png" width="302" />

An abstraction layer for analytics in your app.

<img src="https://github.com/kafejo/Tracker-Aggregator/blob/master/Assets/graph@2x.png" width="555"/>

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

### Binding Event to Property

You can also bind an event to property by implementing the `func generateUpdateEvents() -> [TrackableEvent]` function. This function is called to generate events after the property is updated.

```swift
struct EmailChanged: TrackableEvent {
    let newEmail: String
    
    let identifier: EventIdentifier = EventIdentifier(object: "User", action: "Changed", label: "Email")
    var metadata: [String : Any] { 
        return ["new_email": newEmail] 
    }
}

struct Email: TrackableProperty {
    let identifier: String = "email"                          // Name of the property
    let value: String                                         // Our value, whatever type we need. Enums are handy.

    var trackedValue: TrackableValueType { return value }     // How to convert our value to TrackableValueType
                                                              // String and Int are trackable by default
    func generateUpdateEvents() -> [TrackableEvent] {
        let emailChanged = EmailChanged(newEmail: value)
        return [emailChanged]
    }
}
```

In that way you can just update a email property and the Tracker Aggregator will send the EmailChanged event for you automatically.

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

In your AppDelegate, for example, you can now plug-in your adapters to `GlobalTracker` and call `startTracking(_:)`.

```swift
GlobalTracker.startTracking(adapters: [MixpanelAdapter(token: "abcd")])
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

## Exceptions

In case there's a specific way how to track certain property, just use `switch` or `if` on the property and define required tracking code. For example here is how we at Rubicoin handle Intercom tracker properties

```swift
func track(property: TrackableProperty) {

    switch property {
    case is Property.Email:
        let attrs = ICMUserAttributes()
        attrs.email = property.trackedValue?.stringValue
        Intercom.updateUser(attrs)
    case let property as Property.PushNotificationToken:
        Intercom.setDeviceToken(property.value)
    default:
        let attrs = ICMUserAttributes()
        attrs.customAttributes = [property.identifier: property.trackedValue ?? ""]
        Intercom.updateUser(attrs)
    }
}
```

# Installation
Just copy `TrackerAggregator.swift` to your project.

# License
Tracker Aggregator is under MIT license. See the LICENSE file for more info.
