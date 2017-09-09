//
//  TrackerAggregatorTests.swift
//  TrackerAggregatorTests
//
//  Created by Ales Kocur on 25/08/2017.
//  Copyright © 2017 Rubicoin Ltd. All rights reserved.
//

import XCTest
@testable import TrackerAggregator

class TestableTracker: AnalyticsAdapter {

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
        let testableAdapter = TestableTracker()
        let testEvent = TestEvent()
        let globalTracker = GlobalTracker()

        // when
        globalTracker.set(adapters: [testableAdapter])
        globalTracker.configureAdapters()
        globalTracker.track(event: testEvent)

        // then

        let exp = expectation(description: "Test")

        testableAdapter.trackedEventCallback = {
            XCTAssertNotNil(testableAdapter.trackedEvent, "Event wasn't tracked")
            XCTAssertEqual(testableAdapter.trackedEvent?.identifier.formatted ?? "", "Id: Test")
            XCTAssertEqual((testableAdapter.trackedEvent?.metadata["test"] as? String) ?? "", "m1")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testUserPropertyTracking() {
        // given
        let testableAdapter = TestableTracker()
        let testProperty = TestProperty(value: "New Name")
        let globalTracker = GlobalTracker()

        // when
        globalTracker.set(adapters: [testableAdapter])
        globalTracker.configureAdapters()
        globalTracker.update(property: testProperty)

        // then 

        let exp = expectation(description: "Test")

        testableAdapter.trackedPropertyCallback = {
            XCTAssertNotNil(testableAdapter.trackedProperty, "Property wasn't tracked")
            XCTAssertEqual(testableAdapter.trackedProperty?.identifier ?? "", "name")
            XCTAssertEqual((testableAdapter.trackedProperty?.trackedValue as? String) ?? "", "New Name")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testUpdateEvents() {
        // given
        let testProperty = TestUpdateProperty(value: "New Email")
        let testableAdapter = TestableTracker()
        let globalTracker = GlobalTracker()

        // when

        globalTracker.set(adapters: [testableAdapter])
        globalTracker.configureAdapters()
        globalTracker.update(property: testProperty)

        // then
        let exp = expectation(description: "Test")

        testableAdapter.trackedEventCallback = {
            XCTAssertNotNil(testableAdapter.trackedEvent, "Property wasn't tracked")
            XCTAssertEqual(testableAdapter.trackedEvent?.identifier.formatted ?? "", "Id: Test")
            XCTAssertEqual((testableAdapter.trackedEvent?.metadata["test"] as? String) ?? "", "m1")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testProhibitEventRule() {
        // given
        let testableAdapter = TestableTracker()
        let eventRule = EventTrackingRule(.prohibit, types: [TestEvent.self])
        testableAdapter.eventTrackingRule = eventRule
        let event = TestEvent()
        let globalTracker = GlobalTracker()

        globalTracker.set(adapters: [testableAdapter])

        // when
        globalTracker.track(event: event)
        globalTracker.configureAdapters()

        // then
        let exp = expectation(description: "Test")
        exp.isInverted = true

        testableAdapter.trackedEventCallback = {
            XCTAssertNil(testableAdapter.trackedEvent, "Property was tracked even when rulled out")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testAllowEventRule() {
        // given
        let testableAdapter = TestableTracker()
        let eventRule = EventTrackingRule(.allow, types: [TestEvent.self])
        testableAdapter.eventTrackingRule = eventRule
        let event = TestEvent()
        let globalTracker = GlobalTracker()

        globalTracker.set(adapters: [testableAdapter])
        globalTracker.configureAdapters()

        // when
        globalTracker.track(event: event)

        // then
        let exp = expectation(description: "Test")

        testableAdapter.trackedEventCallback = {
            XCTAssertNotNil(testableAdapter.trackedEvent, "Property wasn't tracked")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testProhibitPropertyRule() {
        // given
        let testableAdapter = TestableTracker()
        let propertyRule = PropertyTrackingRule(.prohibit, types: [TestProperty.self])
        testableAdapter.propertyTrackingRule = propertyRule
        let prohibitedProperty = TestProperty(value: "New Value")

        let globalTracker = GlobalTracker()

        globalTracker.set(adapters: [testableAdapter])

        // when
        globalTracker.update(property: prohibitedProperty)

        // then
        let exp = expectation(description: "Test")
        exp.isInverted = true

        testableAdapter.trackedPropertyCallback = {
            XCTAssertNil(testableAdapter.trackedProperty, "Property was tracked even when rulled out")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }

    func testAllowPropertyRule() {
        // given
        let testableAdapter = TestableTracker()
        let propertyRule = PropertyTrackingRule(.allow, types: [TestProperty.self])
        testableAdapter.propertyTrackingRule = propertyRule
        let prohibitedProperty = TestUpdateProperty(value: "New Value")
        let globalTracker = GlobalTracker()

        globalTracker.set(adapters: [testableAdapter])

        // when
        globalTracker.update(property: prohibitedProperty)

        // then
        let exp = expectation(description: "Test")
        exp.isInverted = true

        testableAdapter.trackedPropertyCallback = {
            XCTAssertNil(testableAdapter.trackedProperty, "Property was tracked even when rulled out")
            exp.fulfill()
        }

        self.waitForExpectations(timeout: 2.0)
    }
}
