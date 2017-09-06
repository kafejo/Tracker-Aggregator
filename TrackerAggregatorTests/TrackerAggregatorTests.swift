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

    var trackedEvent: TrackableEvent? {
        didSet {
            trackedEventCallback?()
        }
    }

    var trackedEventCallback: (() -> Void)? = nil

    func track(event: TrackableEvent) {
        trackedEvent = event
    }

    var trackedPropertyCallback: (() -> Void)? = nil
    var trackedProperty: TrackableProperty? {
        didSet {
            trackedPropertyCallback?()
        }
    }
    
    func track(property: TrackableProperty) {
        trackedProperty = property
    }

    func configure() {
        sleep(1)
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
        let globalTracker = GlobalTracker()

        // when
        globalTracker.set(trackers: [testableTracker])
        globalTracker.configureTrackers()
        globalTracker.trackEvent(event: testEvent)

        // then

        let exp = expectation(description: "Test")

        testableTracker.trackedEventCallback = {
            XCTAssertNotNil(testableTracker.trackedEvent, "Event wasn't tracked")
            XCTAssertEqual(testableTracker.trackedEvent?.identifier.stringValue ?? "", "Id: Test")
            XCTAssertEqual((testableTracker.trackedEvent?.metadata["test"] as? String) ?? "", "m1")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testUserPropertyTracking() {
        // given
        let testableTracker = TestableTracker()
        let testProperty = TestProperty(value: "New Name")
        let globalTracker = GlobalTracker()

        // when
        globalTracker.set(trackers: [testableTracker])
        globalTracker.configureTrackers()
        globalTracker.update(property: testProperty)

        // then 

        let exp = expectation(description: "Test")

        testableTracker.trackedPropertyCallback = {
            XCTAssertNotNil(testableTracker.trackedProperty, "Property wasn't tracked")
            XCTAssertEqual(testableTracker.trackedProperty?.identifier ?? "", "name")
            XCTAssertEqual((testableTracker.trackedProperty?.trackedValue as? String) ?? "", "New Name")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testUpdateEvents() {
        // given
        let testProperty = TestUpdateProperty(value: "New Email")
        let testableTracker = TestableTracker()
        let globalTracker = GlobalTracker()

        // when

        globalTracker.set(trackers: [testableTracker])
        globalTracker.configureTrackers()
        globalTracker.update(property: testProperty)

        // then
        let exp = expectation(description: "Test")

        testableTracker.trackedEventCallback = {
            XCTAssertNotNil(testableTracker.trackedEvent, "Property wasn't tracked")
            XCTAssertEqual(testableTracker.trackedEvent?.identifier.stringValue ?? "", "Id: Test")
            XCTAssertEqual((testableTracker.trackedEvent?.metadata["test"] as? String) ?? "", "m1")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testProhibitEventRule() {
        // given
        let testableTracker = TestableTracker()
        let eventRule = EventTrackingRule(.prohibit, types: [TestEvent.self])
        testableTracker.eventTrackingRule = eventRule
        let event = TestEvent()
        let globalTracker = GlobalTracker()

        globalTracker.set(trackers: [testableTracker])

        // when
        globalTracker.trackEvent(event: event)
        globalTracker.configureTrackers()

        // then
        let exp = expectation(description: "Test")
        exp.isInverted = true

        testableTracker.trackedEventCallback = {
            XCTAssertNil(testableTracker.trackedEvent, "Property was tracked even when rulled out")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testAllowEventRule() {
        // given
        let testableTracker = TestableTracker()
        let eventRule = EventTrackingRule(.allow, types: [TestEvent.self])
        testableTracker.eventTrackingRule = eventRule
        let event = TestEvent()
        let globalTracker = GlobalTracker()

        globalTracker.set(trackers: [testableTracker])
        globalTracker.configureTrackers()

        // when
        globalTracker.trackEvent(event: event)

        // then
        let exp = expectation(description: "Test")

        testableTracker.trackedEventCallback = {
            XCTAssertNotNil(testableTracker.trackedEvent, "Property wasn't tracked")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testProhibitPropertyRule() {
        // given
        let testableTracker = TestableTracker()
        let propertyRule = PropertyTrackingRule(.prohibit, types: [TestProperty.self])
        testableTracker.propertyTrackingRule = propertyRule
        let prohibitedProperty = TestProperty(value: "New Value")

        let globalTracker = GlobalTracker()

        globalTracker.set(trackers: [testableTracker])

        // when
        globalTracker.update(property: prohibitedProperty)

        // then
        let exp = expectation(description: "Test")
        exp.isInverted = true

        testableTracker.trackedPropertyCallback = {
            XCTAssertNil(testableTracker.trackedProperty, "Property was tracked even when rulled out")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testAllowPropertyRule() {
        // given
        let testableTracker = TestableTracker()
        let propertyRule = PropertyTrackingRule(.allow, types: [TestProperty.self])
        testableTracker.propertyTrackingRule = propertyRule
        let prohibitedProperty = TestUpdateProperty(value: "New Value")
        let globalTracker = GlobalTracker()

        globalTracker.set(trackers: [testableTracker])

        // when
        globalTracker.update(property: prohibitedProperty)

        // then
        let exp = expectation(description: "Test")
        exp.isInverted = true

        testableTracker.trackedPropertyCallback = {
            XCTAssertNil(testableTracker.trackedProperty, "Property was tracked even when rulled out")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }
}
