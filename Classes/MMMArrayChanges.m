//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

#import "MMMArrayChanges.h"

// Alias class parameters so we can use the same definitions as in the header.
typedef id NewItemType;
typedef id OldItemType;

@implementation MMMArrayChanges

+ (instancetype)zero {

	static MMMArrayChanges *zero = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		zero = [[MMMArrayChanges alloc] initWithRemovals:@[] insertions:@[] moves:@[] updates:@[]];
	});

	return zero;
}

+ (instancetype)changesWithOldArray:(NSArray<OldItemType> *)oldArray newArray:(NSArray<NewItemType> *)newArray {

	return [self
		changesWithOldArray:oldArray 
		idFromItemBlock:^id(id item) {
			return item;
		}
		newArray:newArray
		idFromItemBlock:^id(id item) {
			return item;
		}
		comparisonBlock:^BOOL(id oldItem, id newItem) {
			return [oldItem isEqual:newItem];
		}
	];
}

+ (instancetype)changesWithOldArray:(NSArray *)oldArray
	idFromItemBlock:(id (NS_NOESCAPE^)(OldItemType item))oldIdFromItemBlock
	newArray:(NSArray<NewItemType> *)newArray
	idFromItemBlock:(id (NS_NOESCAPE^)(NewItemType item))newIdFromItemBlock
	comparisonBlock:(BOOL (NS_NOESCAPE^)(OldItemType oldItem, NewItemType newItem))comparisonBlock
{
	//
	// First let's check if the arrays are the same, this should be the most common situation.
	//
	if (oldArray.count == newArray.count) {

		NSInteger i = 0;
		for (; i < oldArray.count; i++) {
			if (![oldIdFromItemBlock(oldArray[i]) isEqual:newIdFromItemBlock(newArray[i])])
				break;
		}

		if (i >= oldArray.count) {

			// OK, all items have the same positions, nothing was added or removed, let's only check if their contents is the same.
			NSMutableArray *updates = nil;
			if (comparisonBlock) {
				for (i = 0; i < oldArray.count; i++) {
					if (!comparisonBlock(oldArray[i], newArray[i])) {
						if (!updates)
							updates = [[NSMutableArray alloc] init];
						[updates addObject:[[MMMArrayChangesUpdate alloc] initWithOldIndex:i newIndex:i]];
					}
				}
			}
			if (!updates) {
				// OK, all objects are the same down to their contents, no changes.
				return [self zero];
			} else {
				// Only changed contents of some of the objects.
				return [[MMMArrayChanges alloc] initWithRemovals:@[] insertions:@[] moves:@[] updates:updates];
			}
		}
	}

	//
	// Now let's index all the items.
	//

	// intermediateOld[i] will be an index of the object in the oldArray at i-th place after all removals are performed.
	NSMutableArray *intermediate = [[NSMutableArray alloc] init];
	for (NSInteger i = 0; i < oldArray.count; i++) {
		[intermediate addObject:@(i)];
	}

	// All IDs from the old array.
	NSMutableSet *oldIds = [[NSMutableSet alloc] init];
	// If we detect duplicate IDs in the old array (something that should not be there),
	// then we record the indexes of those elements here to remove the corresponding elements below.
	NSMutableSet<NSNumber *> *oldDuplicates = nil;
	for (NSInteger i = 0; i < oldArray.count; i++) {

		// Getting count to detect if the item has been added or ignored as a duplicate,
		// this way we avoid checking this explicitely.
		NSInteger count = oldIds.count;

		[oldIds addObject:oldIdFromItemBlock(oldArray[i])];

		if (oldIds.count == count) {
			// It looks like there is an item with the same ID somewhere before in the old array.
			// Technically this is not the thing we have signed up for, but well, let's remove them as an extra service.
			if (!oldDuplicates) {
				oldDuplicates = [[NSMutableSet alloc] init];
			}
			[oldDuplicates addObject:@(i)];
		}
	}

	// All IDs from the new array.
	NSMutableSet *newIds = [[NSMutableSet alloc] init];
	for (NSInteger i = 0; i < newArray.count; i++) {
		[newIds addObject:newIdFromItemBlock(newArray[i])];
	}

	// Removals.
	NSMutableArray *removals = [[NSMutableArray alloc] init];
	for (NSInteger i = oldArray.count - 1; i >= 0; i--) {
		// Removing those items in the old array that don't have a corresponding element in the new one
		// or are duplicates of items in the old array.
		if (![newIds containsObject:oldIdFromItemBlock(oldArray[i])]
			|| (oldDuplicates && [oldDuplicates containsObject:@(i)])
		) {
			[removals addObject:[[MMMArrayChangesRemoval alloc] initWithIndex:i]];
			[intermediate removeObjectAtIndex:i];
		}
	}

	// Insertions.
	NSMutableArray *insertions = [[NSMutableArray alloc] init];
	for (NSInteger i = 0; i < newArray.count; i++) {
		// Elements of the new array that are not in the old are, well, new.
		if (![oldIds containsObject:newIdFromItemBlock(newArray[i])]) {
			[insertions addObject:[[MMMArrayChangesInsertion alloc] initWithIndex:i]];
		}
	}

	// Moves and updates.
	NSMutableArray *moves = [[NSMutableArray alloc] init];
	NSMutableArray *updates = [[NSMutableArray alloc] init];

	NSInteger intermediateTargetIndex = 0;
	for (NSInteger newIndex = 0; newIndex < newArray.count; newIndex++) {

		id newItem = newArray[newIndex];
		id newId = newIdFromItemBlock(newItem);

		if ([oldIds containsObject:newId]) {

			NSInteger oldIndex = [intermediate[intermediateTargetIndex] integerValue];
			id oldItem = oldArray[oldIndex];
			id oldId = oldIdFromItemBlock(oldItem);

			if ([oldId isEqual:newId]) {

				// The item is at its target position already, let's only check if the contents has changed.

				if (comparisonBlock && !comparisonBlock(oldItem, newItem)) {
					// OK, the content has changed, let's record an update.
					[updates addObject:[[MMMArrayChangesUpdate alloc] initWithOldIndex:oldIndex newIndex:newIndex]];
				}

			} else {

				// A different element here, need a movement.

				// Let's find where this element is in the old array.
				// TODO: this reverse look up can be improved
				NSInteger oldNewIndex = NSNotFound;
				id oldNewItem = nil;
				NSInteger intermediateSourceIndex = 0;
				for (; intermediateSourceIndex < intermediate.count; intermediateSourceIndex++) {
					oldNewIndex = [intermediate[intermediateSourceIndex] integerValue];
					oldNewItem = oldArray[oldNewIndex];
					if ([oldIdFromItemBlock(oldNewItem) isEqual:newId])
						break;
				}
				NSAssert(oldNewIndex != NSNotFound && intermediateSourceIndex < intermediate.count, @"");

				// Record a move.
				[moves addObject:[[MMMArrayChangesMove alloc]
					initWithOldIndex:oldNewIndex newIndex:newIndex
					intermediateSourceIndex:intermediateSourceIndex intermediateTargetIndex:intermediateTargetIndex
				]];

				// Update the intermediate array accordingly.
				id t = intermediate[intermediateSourceIndex];
				[intermediate removeObjectAtIndex:intermediateSourceIndex];
				[intermediate insertObject:t atIndex:intermediateTargetIndex];

				// Check if the item has content changes as well.
				if (comparisonBlock && !comparisonBlock(oldNewItem, newItem)) {
					// Yes, record an update, too.
					[updates addObject:[[MMMArrayChangesUpdate alloc] initWithOldIndex:oldNewIndex newIndex:newIndex]];
				}
			}

			intermediateTargetIndex++;
		}
	}

	return [[MMMArrayChanges alloc] initWithRemovals:removals insertions:insertions moves:moves updates:updates];
}

- (id)initWithRemovals:(NSArray *)removals insertions:(NSArray *)insertions moves:(NSArray *)moves updates:(NSArray *)updates {

	if (self = [super init]) {

		_removals = removals;
		_insertions = insertions;
		_moves = moves;
		_updates = updates;

		_empty = (_removals.count == 0) && (_insertions.count == 0) && (_moves.count == 0) && (_updates.count == 0);
	}

	return self;
}

- (NSString *)description {

	if (self.empty) {
		return [NSString stringWithFormat:@"<%@: empty>", self.class];
	}

	NSMutableArray *changes = [[NSMutableArray alloc] init];
	[changes addObjectsFromArray:self.removals];
	[changes addObjectsFromArray:self.insertions];
	[changes addObjectsFromArray:self.moves];
	[changes addObjectsFromArray:self.updates];

	NSMutableString *changesString = [[NSMutableString alloc] init];
	for (id c in changes) {
		[changesString appendFormat:@"\t%@\n", c];
	}

	return [NSString stringWithFormat:@"<%@: changes:\n%@>", self.class, changesString];
}

- (void)applyToArray:(NSMutableArray *)oldArray
	newArray:(NSArray *)newArray
	newItemBlock:(id (NS_NOESCAPE^)(NewItemType newItem))newItemBlock
	updateBlock:(void (NS_NOESCAPE^)(OldItemType oldItem, NewItemType newItem))updateBlock
{
	[self
		applyToArray:oldArray
		newArray:newArray
		newItemBlock:newItemBlock
		updateBlock:updateBlock
		removalBlock:nil
	];
}

- (void)applyToArray:(NSMutableArray *)oldArray
	newArray:(NSArray<NewItemType> *)newArray
	newItemBlock:(id (NS_NOESCAPE^)(NewItemType newItem))newItemBlock
	updateBlock:(void (NS_NOESCAPE^)(OldItemType oldItem, NewItemType newItem))updateBlock
	removalBlock:(void (NS_NOESCAPE^)(OldItemType oldItem))removalBlock
{
	// Removals have reverse order, so we don't have to adjust indexes
	for (MMMArrayChangesRemoval *r in self.removals) {
		id item = oldArray[r.index];
		[oldArray removeObjectAtIndex:r.index];
		if (removalBlock)
			removalBlock(item);
	}

	// Now the moves, their source/target indexes are relative the current state of the array.
	for (MMMArrayChangesMove *m in self.moves) {
		id item = oldArray[m.intermediateSourceIndex];
		[oldArray removeObjectAtIndex:m.intermediateSourceIndex];
		[oldArray insertObject:item atIndex:m.intermediateTargetIndex];
	}

	// And finally the insertions and updates.
	for (MMMArrayChangesInsertion *i in self.insertions) {

		id object = newItemBlock(newArray[i.index]);

		// It's not allowed to have nil items, but still trying to not fail in production by putting NSNull's now
		// and removing them afterwards.
		// Well, we could allow NSNull, but then we'll have to use something else as our placeholder that we remove below.
		if (!object || object == (id)[NSNull null]) {
			NSAssert(NO, @"newItemBlock cannot return nil or NSNull");
			object = [NSNull null];
		}

		[oldArray insertObject:object atIndex:i.index];
	}

	// OK, let's make sure to filter all the NSNull's inserted above.
	for (NSInteger i = oldArray.count - 1; i >= 0; i--) {
		if (oldArray[i] == (id)[NSNull null])
			[oldArray removeObjectAtIndex:i];
	}

	if (updateBlock) {
		for (MMMArrayChangesUpdate *u in self.updates) {
			// Note that 'newIndex' is used in both cases because the old array is the same as the new one (except for updates).
			updateBlock(oldArray[u.newIndex], newArray[u.newIndex]);
		}
	}
}

- (void)applyToTableView:(UITableView *)tableView
	indexPathForItemIndexBlock:(NSIndexPath* (NS_NOESCAPE ^)(NSInteger row))indexPathForItemIndexBlock
	deletionAnimation:(UITableViewRowAnimation)deletionAnimation
	insertionAnimation:(UITableViewRowAnimation)insertionAnimation
{
	if (self.empty)
		return;

	// The order is very important here: 1) deletions, 2) insertions, 3) moves.

	[tableView beginUpdates];

	NSMutableArray *removalsIndexPaths = [[NSMutableArray alloc] initWithCapacity:_removals.count];
	for (MMMArrayChangesRemoval *r in _removals) {
		[removalsIndexPaths addObject:indexPathForItemIndexBlock(r.index)];
	}
	[tableView deleteRowsAtIndexPaths:removalsIndexPaths withRowAnimation:deletionAnimation];

	NSMutableArray *insertionsIndexPaths = [[NSMutableArray alloc] initWithCapacity:_insertions.count];
	for (MMMArrayChangesInsertion *i in _insertions) {
		[insertionsIndexPaths addObject:indexPathForItemIndexBlock(i.index)];
	}
	[tableView insertRowsAtIndexPaths:insertionsIndexPaths withRowAnimation:insertionAnimation];

	for (MMMArrayChangesUpdate *update in _updates) {
		if (update.oldIndex != update.newIndex) {
			[tableView
				moveRowAtIndexPath:indexPathForItemIndexBlock(update.oldIndex)
				toIndexPath:indexPathForItemIndexBlock(update.newIndex)
			];
		}
	}
	
	[tableView endUpdates];
}

@end


//
//
//
@implementation MMMArrayChangesInsertion

- (id)initWithIndex:(NSInteger)index {

	if (self = [super init]) {
		_index = index;
	}

	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"+%ld", (long)_index];
}

@end

//
//
//
@implementation MMMArrayChangesRemoval

- (id)initWithIndex:(NSInteger)index {

	if (self = [super init]) {
		_index = index;
	}

	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"-%ld", (long)_index];
}

@end

//
//
//
@implementation MMMArrayChangesMove

- (id)initWithOldIndex:(NSInteger)oldIndex
	newIndex:(NSInteger)newIndex
	intermediateSourceIndex:(NSInteger)intermediateSourceIndex
	intermediateTargetIndex:(NSInteger)intermediateTargetIndex
{

	if (self = [super init]) {
		_oldIndex = oldIndex;
		_newIndex = newIndex;
		_intermediateSourceIndex = intermediateSourceIndex;
		_intermediateTargetIndex = intermediateTargetIndex;
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%ld -> %ld", (long)_oldIndex, (long)_newIndex];
}

@end

//
//
//
@implementation MMMArrayChangesUpdate

- (id)initWithOldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex {

	if (self = [super init]) {

		_oldIndex = oldIndex;
		_newIndex = newIndex;

	}

	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%ld -> *%ld", (long)_oldIndex, (long)_newIndex];
}

@end
