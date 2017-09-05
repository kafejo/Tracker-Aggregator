//
//  TrackerAggregatorTests.swift
//  TrackerAggregatorTests
//
//  Created by Ales Kocur on 25/08/2017.
//  Copyright © 2017 Rubicoin Ltd. All rights reserved.
//

import XCTest
@testable import TrackerAggregator

class TestableTracker: Tracker {

    var eventTrackingRule: EventTrackingRule? = nil
    var propertyTrackingRule: PropertyTrackingRule? = nil

    var trackedEvent: TrackableEvent?

    func track(event: TrackableEvent) {
        trackedEvent = event
    }

    var trackedProperty: TrackableProperty?
    func track(property: TrackableProperty) {
        trackedProperty = property
    }

    func configure() {

    }
}

struct TestEvent: TrackableEvent {
    let identifier: EventIdentifier = EventIdentifier(object: "Id", action: "Test")
    let metadata: [String : Any] = ["test": "m1"]
}

struct TestEvent2: TrackableEvent {
    let identifier: EventIdentifier = EventIdentifier(object: "Id2", action: "Test2")
    let metadata: [String : Any] = ["test": "m1"]
}

struct TestProperty: TrackableProperty {
    let identifier: String = "name"
    let value: String

    var trackedValue: TrackableValueType { return value }
}

struct TestUpdateProperty: TrackableProperty {
    let identifier: String = "name2"
    let value: String

    var trackedValue: TrackableValueType { return value }

    func generateUpdateEvents() -> [TrackableEvent] {
        return [TestEvent()]
    }
}

class TrackerAggregatorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEventTracking() {
        // given
        let testableTracker = TestableTracker()
        let testEvent = TestEvent()

        // when
        GlobalTracker.set(trackers: [testableTracker])
        GlobalTracker.trackEvent(event: testEvent)

        // then
        XCTAssertNotNil(testableTracker.trackedEvent, "Event wasn't tracked")
        XCTAssertEqual(testableTracker.trackedEvent?.identifier.stringValue ?? "", "Id: Test")
        XCTAssertEqual((testableTracker.trackedEvent?.metadata["test"] as? String) ?? "", "m1")
    }

    func testUserPropertyTracking() {
        // given
        let testableTracker = TestableTracker()
        let testProperty = TestProperty(value: "New Name")

        // when
        GlobalTracker.set(trackers: [testableTracker])
        GlobalTracker.update(property: testProperty)

        // then 
        XCTAssertNotNil(testableTracker.trackedProperty, "Property wasn't tracked")
        XCTAssertEqual(testableTracker.trackedProperty?.identifier ?? "", "name")
        XCTAssertEqual((testableTracker.trackedProperty?.trackedValue as? String) ?? "", "New Name")
    }

    func testUpdateEvents() {
        // given
        let testProperty = TestUpdateProperty(value: "New Email")
        let testableTracker = TestableTracker()

        // when
        GlobalTracker.set(trackers: [testableTracker])
        GlobalTracker.update(property: testProperty)

        // then
        XCTAssertNotNil(testableTracker.trackedEvent, "Property wasn't tracked")
        XCTAssertEqual(testableTracker.trackedEvent?.identifier.stringValue ?? "", "Id: Test")
        XCTAssertEqual((testableTracker.trackedEvent?.metadata["test"] as? String) ?? "", "m1")
    }

    func testProhibitEventRule() {
        // given
        let testableTracker = TestableTracker()
        let eventRule = EventTrackingRule(.prohibit, types: [TestEvent.self])
        testableTracker.eventTrackingRule = eventRule
        let event = TestEvent()
        let event2 = TestEvent2()

        GlobalTracker.set(trackers: [testableTracker])

        // when
        GlobalTracker.trackEvent(event: event)

        // then
        XCTAssertNil(testableTracker.trackedEvent, "Property was tracked even when rulled out")

        // when
        testableTracker.trackedEvent = nil
        GlobalTracker.trackEvent(event: event2)

        // then
        XCTAssertNotNil(testableTracker.trackedEvent, "Property wasn't tracked")
    }

    func testAllowEventRule() {
        // given
        let testableTracker = TestableTracker()
        let eventRule = EventTrackingRule(.allow, types: [TestEvent.self])
        testableTracker.eventTrackingRule = eventRule
        let event = TestEvent()
        let event2 = TestEvent2()

        GlobalTracker.set(trackers: [testableTracker])

        // when
        GlobalTracker.trackEvent(event: event)

        // then
        XCTAssertNotNil(testableTracker.trackedEvent, "Property wasn't tracked")

        // when
        testableTracker.trackedEvent = nil
        GlobalTracker.trackEvent(event: event2)

        // then
        XCTAssertNil(testableTracker.trackedEvent, "Property was tracked even when rulled out")
    }

    func testProhibitPropertyRule() {
        // given
        let testableTracker = TestableTracker()
        let propertyRule = PropertyTrackingRule(.prohibit, types: [TestProperty.self])
        testableTracker.propertyTrackingRule = propertyRule
        let prohibitedProperty = TestProperty(value: "New Value")
        let allowedProperty = TestUpdateProperty(value: "New Value")
        GlobalTracker.set(trackers: [testableTracker])

        // when
        GlobalTracker.update(property: prohibitedProperty)

        // then
        XCTAssertNil(testableTracker.trackedProperty, "Property was tracked even when rulled out")

        // when
        testableTracker.trackedProperty = nil
        GlobalTracker.update(property: allowedProperty)

        // then
        XCTAssertNotNil(testableTracker.trackedProperty, "Property wasn't tracked")
    }

    func testAllowPropertyRule() {
        // given
        let testableTracker = TestableTracker()
        let propertyRule = PropertyTrackingRule(.allow, types: [TestProperty.self])
        testableTracker.propertyTrackingRule = propertyRule
        let allowedProperty = TestProperty(value: "New Value")
        let prohibitedProperty = TestUpdateProperty(value: "New Value")
        GlobalTracker.set(trackers: [testableTracker])

        // when
        GlobalTracker.update(property: prohibitedProperty)

        // then
        XCTAssertNil(testableTracker.trackedProperty, "Property was tracked even when rulled out")

        // when
        testableTracker.trackedProperty = nil
        GlobalTracker.update(property: allowedProperty)

        // then
        XCTAssertNotNil(testableTracker.trackedProperty, "Property wasn't tracked")
    }
}
