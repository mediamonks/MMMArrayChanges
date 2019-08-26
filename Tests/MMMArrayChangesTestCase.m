//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <MMMArrayChanges/MMMArrayChanges.h>

@interface MMMArrayChangesTestCase : XCTestCase
@end

@implementation MMMArrayChangesTestCase

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
