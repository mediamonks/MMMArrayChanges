//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <MMMArrayChanges/MMMArrayChanges.h>

@interface MMMArrayChangesTestCase : XCTestCase
@end

@implementation MMMArrayChangesTestCase

- (void)testBasics {
	// `MMMArrayChanges` class can also be used to find differences between two arrays.
	// It should be slower than `diffMap()`, but it plays well with ObjC and all the changes reported are compatible
	// with what `UITableView` expects between beginUpdates()/endUpdates() (information about movemenets
	// of elements is also generated).
}

- (void)verifyApplyWithOldArray:(NSArray *)oldArray newArray:(NSArray *)newArray {

	MMMArrayChanges *changes = [MMMArrayChanges
		changesWithOldArray:oldArray
		idFromItemBlock:^id(id item) {
			return item;
		}
		newArray:newArray
		idFromItemBlock:^id(id item) {
			return item;
		}
		comparisonBlock:^BOOL(id oldItem, id newItem) {
			return YES;
		}
	];
	NSMutableArray *test = [NSMutableArray arrayWithArray:oldArray];
	[changes
		applyToArray:test
		newArray:newArray
		newItemBlock:^id(id newItem) {
			return newItem;
		}
		updateBlock:^(id oldItem, id newItem) {
		}
	];
	XCTAssertEqualObjects(test, newArray);
}

- (void)testApplyToArray {
	[self
		verifyApplyWithOldArray:@[ @1, @2, @3 ]
		newArray:@[ @2, @10, @1, @3 ]
	];
	[self
		verifyApplyWithOldArray:@[ @0, @1, @2, @3, @4, @5, @6 ]
		newArray:@[ @4, @10, @3, @11, @0, @1, @5 ]
	];
}

@end
