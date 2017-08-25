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

    let eventTrackingRule: EventTrackingRule? = nil
    let propertyTrackingRule: PropertyTrackingRule? = nil

    var trackedEvent: TrackableEvent?

    func track(event: TrackableEvent) {
        trackedEvent = event
    }

    var trackedProperty: TrackableProperty?
    func track(property: TrackableProperty) {
        trackedProperty = property
    }
}

struct TestEvent: TrackableEvent {
    let identifier: String = "id"
    let metadata: [String : Any] = ["test": "m1"]
}

struct TestProperty: TrackableProperty {
    let identifier: String = "name"
    let value: String

    var trackedValue: TrackableValueType { return value }
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
        XCTAssertEqual(testableTracker.trackedEvent?.identifier ?? "", "id")
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

}
