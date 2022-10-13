<img src="https://github.com/kafejo/Tracker-Aggregator/blob/master/Assets/logo-text@2x.png" width="302" />

An abstraction layer for analytics in your app to help you organise your analytics code in your app. Think of it as a local [Rudderstack](https://www.rudderstack.com) or [Segment](https://segment.com).

<img src="https://github.com/kafejo/Tracker-Aggregator/blob/master/Assets/graph@2x.png" width="555"/>

```swift
Events.App.Opened(appName: "My App").trigger()
// Based on your rules it will be sent to your adapters (e.g. Intercom, Firebase, Mixpanel, …)
```

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

## Quick start

### Define your events

```swift
// MyEvents.swift
struct Events {
    struct App {
        static let name = "App"
        
        struct Opened: TrackableEvent {
            let appName: String

            let identifier = EventIdentifier(object: name, action: "Opened")

            var metadata: [String: Any] {
                return [
                    "name": appName
                ]
            }
        }
    }
}
```

### Create adapters

```swift
import Mixpanel

class MixpanelAdapter: AnalyticsAdapter {

    private let token: String

    init(token: String) {
        self.token = token
    }
 
    // This is called when we start tracking
    func configure() {
        _ = Mixpanel.sharedInstance(withToken: token)
    }

    // This is called when the adapter receives an event
    func track(event: TrackableEvent) {
        // Track event in Mixpanel
        Mixpanel.sharedInstance()?.track(event.identifier.stringValue, properties: event.metadata)
    }

    // This is called when the adapter receives a property
    func track(property: TrackableProperty) {
        // Track property in Mixpanel
        Mixpanel.sharedInstance()?.people.set(property.identifier, to: property.trackedValue)
    }
}
```

### Start tracking

```swift
// AppDelegate.swift
GlobalTracker.startTracking(adapters: [MixpanelAdapter(token: "abcd")])
```

then somewhere in your code

```swift
Events.App.Opened(appName: "My App").trigger()
```

Trigger method just simply calls the event on `GlobalTracker` that forwards it to all plugged analytics adapters if they support it (e.g. Intercom, Firebase, Mixpanel, …). Later you will learn how to setup adapter rules so they receive only some events or properties if needed.

# More Details 

## Defining events

To define an event you need a struct that conforms to `TrackableEvent` protocol. 

```swift
struct AppOpen: TrackableEvent {
    let timestamp: Date
    
    let identifier: EventIdentifier = EventIdentifier(object: "App", action: "Open")
    var metadata: [String : Any] { 
        return ["timestamp": dateFormatter.string(from: timestamp)] 
    }
}
```

The structure is up to you but I like to do nest it based on the objects / screens. e.g.

```swift
struct Events {
    struct User {
        static let name = "User"
        
        struct LoggedIn: TrackableEvent {
            let identifier: EventIdentifier(object: name, action: "Logged In")
        }
        
        struct LoggedOut: TrackableEvent {
            let identifier: EventIdentifier(object: name, action: "Logged Out")
        }
        
        struct ProfileUpdated: TrackableEvent {
            let newName: String
            let identifier: EventIdentifier(object: name, action: "Profile Updated")
            var metadata: [String: Any] {
                return ["new_name": newName]
            }
        }
    }
}
```

This allow for nice structure (and autocompletion) when triggering events.

```swift
Events.User.LoggedIn().trigger()
Events.User.ProfileUpdated(newName: "Alfred").trigger()
```

## Track property

Similarly to event tracking, we define a struct that represents our property by conforming it to `TrackableProperty` protocol

```swift
struct Email: TrackableProperty {
    let identifier: String = "email"                          // Name of the property
    let value: String                                         // Our value, whatever type we need. Enums are handy.

    var trackedValue: TrackableValueType? { return value }     // How to convert our value to TrackableValueType
                                                             // String and Int are trackable by default
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

We create simple classes that encapsulate each analytic tool logic by conforming them to `AnalyticsAdapter` protocol. 

```swift
import Mixpanel

class MixpanelAdapter: AnalyticsAdapter {

    private let token: String

    // Optional name for nice logs. By default the class name is used (e.g. `MixpanelAdapter`)
    var name: String { "Mixpanel" }
    
    init(token: String) {
        self.token = token
    }
 
    // This method is when the tracking is about to start
    func configure() {
        _ = Mixpanel.sharedInstance(withToken: token)
    }

    // This is called when the adapter receives an event to track
    func track(event: TrackableEvent) {
        // Track event in Mixpanel
        Mixpanel.sharedInstance()?.track(event.identifier.stringValue, properties: event.metadata)
    }

    // This is called when the adapter receives a property to track
    func track(property: TrackableProperty) {
        // Track property in Mixpanel
        Mixpanel.sharedInstance()?.people.set(property.identifier, to: property.trackedValue)
    }
}
```

In your AppDelegate, for example, you can now plug-in your adapters to `GlobalTracker` by calling `startTracking(adapters:)`.

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

There are two types of rules `.allow` or `.prohibit`. 

### Allow
The adapter only receives events included in the allowed types.

```swift
let eventTrackingRule: EventTrackingRule? = EventTrackingRule(.allow, types: 
    [
        Events.App.Open.self,
        Events.User.LogIn.self
    ]
)
```
In this example the tracker will not receive any other event than the 2 defined in the rule.

### Prohibit
The adapter receives all events beside the events included in the prohibited types.

```swift
let eventTrackingRule: EventTrackingRule? = EventTrackingRule(.allow, types: 
    [
        Events.App.Open.self,
        Events.User.LogIn.self
    ]
)
```
In this example the tracker will receive all events but the 2 defined in the rule.

The same mechanism works for properies, just define `propertyTrackingRule` in your adapter.

## Exceptions

In case there's a specific way how to track certain property, just use `switch` or `if` on the property and define required tracking code. For example here is custom handling of Intercom tracker properties

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

# Logging

There are 3 logging levels - `.none`, `.info`, `.verbose`. 
```swift
GlobalTracker.loggingLevel = .info // default is .none
```

## Info 

The info prints only the name of the event and where it was sent
```
-[Intercom]: EVENT TRIGGERED - 'Event Detail: Viewed'
```

## Verbose
Verbose prints also the metadata.

```
-[Intercom]: EVENT TRIGGERED - 'Event Detail: Viewed' 
 > event_id: 21421
 > state: rendering
```

## Custom Logger
By default things are just `print()`ed. If you use custom logging system you can easily integrate it by setting your own log callback.

```swift
GlobalTracker.log { message in
    SwiftyBeaver.log.info(message) // Log with your favourite logging system
}
```

# Installation
Just copy `TrackerAggregator.swift` to your project.

# License
Developed and maintained by Ales Kocur (ales@spurrapp.com).
Tracker Aggregator is under MIT license. See the LICENSE file for more info.
