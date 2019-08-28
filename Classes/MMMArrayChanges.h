//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MMMArrayChangesInsertion;
@class MMMArrayChangesMove;
@class MMMArrayChangesRemoval;
@class MMMArrayChangesUpdate;

/**
 * Finds differences between two arrays with elements possibly of different types. (To get better autocompletion in ObjC
 * you can specify these types as parameters, e.g. `MMMArrayChanges<MyListItem *, FIRDatabaseSnapshot *>`.)
 *
 * This is to help with detection of changes in a collection of items in general and in particular to have these changes
 * compatible with expectations of `UITableView`.
 *
 * A typical use case is when we sync a list of items with a backend periodically and want to properly animate all
 * the changes in the table view using batch updates.
 *
 * Note that in order to remain compatible with `UITableView` the indexes for removals and the source indexes
 * for moves are always relative to the old array without any changes perfomed on it yet, while the target indexes
 * for moves and the indexes of insertions are relative to the new array.
 */
@interface MMMArrayChanges <OldItemType : id, NewItemType : id> : NSObject

/** 
 * Finds UITableView-compatible differences between two arrays consisting of elements of different types.
 *
 * The `oldIdFromItemBlock` and `newIdFromItemBlock` blocks should be able to provide sort of an ID for each
 * element of the old and new arrays. These should be hashable, properly support isEqual:, and IDs obtained from the old
 * array must be comparable to the ones obtained from the new one.
 *
 * The `comparisonBlock` is called for items having the same ID to figure out if any inner properties of the item have
 * changed enough to mark the corresponding item as "updated" (e.g. to require a reload of a corresponding table view cell).
 */
+ (nonnull instancetype)changesWithOldArray:(NSArray *)oldArray
	idFromItemBlock:(_Nonnull id (NS_NOESCAPE ^)(OldItemType _Nonnull item))oldIdFromItemBlock
	newArray:(NSArray<NewItemType> *)newArray
	idFromItemBlock:(_Nonnull id (NS_NOESCAPE ^)(NewItemType _Nonnull item))newIdFromItemBlock
	comparisonBlock:(BOOL (NS_NOESCAPE ^)(OldItemType _Nonnull oldItem, NewItemType _Nonnull newItem))comparisonBlock;

/** 
 * Finds UITableView-compatible differences between two arrays having elements of the same hashable type that can be 
 * compared with isEqual.
 *
 * (This is a shortcut for the more general version above.)
 */
+ (nonnull instancetype)changesWithOldArray:(NSArray<OldItemType> *)oldArray newArray:(NSArray<NewItemType> *)newArray;

/** YES, if there is no difference between an old and a new arrays. */
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

@property (nonatomic, readonly) NSArray<MMMArrayChangesRemoval *> *removals;
@property (nonatomic, readonly) NSArray<MMMArrayChangesInsertion *> *insertions;
@property (nonatomic, readonly) NSArray<MMMArrayChangesMove *> *moves;

/** 
 * This one is a bit tricky for UITableView: removals, insertions and moves of the corresponding cells can be perfomed 
 * within the same beginUpdates/endUpdates block; however the reloads corresponding to updates should be performed
 * either before or after the above within its own beginUpdates/endUpdates block (make sure to use corresponding indexes).
 * This is because UITableView does not allow for a cell to move and reload at the same time. (Only moving a cell that
 * has changed contents/size would not be enough.)
 */
@property (nonatomic, readonly) NSArray<MMMArrayChangesUpdate *> *updates;

/** 
 * Applies the changes represented by this object to the given array:
 * - `newItemBlock` should be able to create a new item for the "old array" from a corresponding item of the new array;
 * - the optional `updateBlock` is called to modify an old item based on the corresponding item from the new array;
 * - the optional `removalBlock` is called for every item being removed (after it is removed from the array but before
 *   new items are added or moves made).
 */
- (void)applyToArray:(NSMutableArray *)oldArray
	newArray:(NSArray<NewItemType> *)newArray
	newItemBlock:(id (NS_NOESCAPE ^)(NewItemType newItem))newItemBlock
	updateBlock:(void (NS_NOESCAPE ^ __nullable)(OldItemType oldItem, NewItemType newItem))updateBlock
	removalBlock:(void (NS_NOESCAPE ^ __nullable)(OldItemType oldItem))removalBlock
		NS_SWIFT_UNAVAILABLE("In Swift use Array.apply<>(changes:newArray:transform:update:remove:) instead");

/** A shortcut for the above method without the removalBlock. */
- (void)applyToArray:(NSMutableArray *)oldArray
	newArray:(NSArray *)newArray
	newItemBlock:(id (NS_NOESCAPE ^)(NewItemType newItem))newItemBlock
	updateBlock:(void (NS_NOESCAPE ^ __nullable)(OldItemType oldItem, NewItemType newItem))updateBlock
		NS_SWIFT_UNAVAILABLE("In Swift use Array.apply<>(changes:newArray:transform:update:) instead");

/**
 * Replays updates corresponding to the changes represented by the receiver onto `UITableView`.
 *
 * @param indexPathForItemIndex A block that can return an index path corresponding to the index of the element
 * either in the new or the old arrays. I.e. it can only customize the section or provide fixed shift of the row index.
 *
 * Updates without actual movements (updates where old and new indexes are the same) are not applied here, because:
 *
 * 1) The refresh of the contents of cells is normally handled by the cells themeselves observing
 *    the corresponding view models.
 *
 * 2) Reloads cannot be requested within the same begin/endUpdate() transaction anyway.
 *
 * The index paths of such 'updated' but not moved cells are returned so you could still reload them if needed
 * (one case would be if your updated cells might change their height).
 */
- (NSArray<NSIndexPath *> *)applyToTableView:(UITableView *)tableView
	indexPathForItemIndex:(NSIndexPath* (NS_NOESCAPE ^)(NSInteger row))indexPathForItemIndex
	deletionAnimation:(UITableViewRowAnimation)deletionAnimation
	insertionAnimation:(UITableViewRowAnimation)insertionAnimation;

#pragma mark -

- (id)initWithRemovals:(NSArray *)removals
	insertions:(NSArray *)insertions
	moves:(NSArray *)moves
	updates:(NSArray<MMMArrayChangesUpdate *> *)updates NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

@end

/** 
 * To represent a removal of an old object. 
 */
@interface MMMArrayChangesRemoval : NSObject

/** The index of the object being removed in the *old* array. */
@property (nonatomic, readonly) NSInteger index;

- (id)initWithIndex:(NSInteger)index NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

@end

/** 
 * To represent insertion of a new object.
 */
@interface MMMArrayChangesInsertion : NSObject

/** The index of the inserted object in the *new* array. */
@property (nonatomic, readonly) NSInteger index;

- (id)initWithIndex:(NSInteger)index NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

@end

/** 
 * To represent an object at source index being moved into a place with the target index.
 */
@interface MMMArrayChangesMove : NSObject

/** The index of the object being moved in the *old* array. */
@property (nonatomic, readonly) NSInteger oldIndex;

/** The index of the object being moved in the *new* array. */
@property (nonatomic, readonly) NSInteger newIndex;

/** @{ */

/** 
 * These are not needed for the table view, but handy when need to replay the changes on a normal array.
 * An intermediate array is the old one after all the removals applied but before any insertions are made. 
 * The indexes also take into account moves performed before the current one.
 */
@property (nonatomic, readonly) NSInteger intermediateSourceIndex;
@property (nonatomic, readonly) NSInteger intermediateTargetIndex;

/** @} */

- (id)initWithOldIndex:(NSInteger)oldIndex
	newIndex:(NSInteger)newIndex
	intermediateSourceIndex:(NSInteger)intermediateSourceIndex
	intermediateTargetIndex:(NSInteger)intermediateTargetIndex
	NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

@end

/**
 * To describe objects that have changed.
 */
@interface MMMArrayChangesUpdate : NSObject

/** The index of the changed object in the *old* array. */
@property (nonatomic, readonly) NSInteger oldIndex;

/** The index of the changed object in the *new* array. */
@property (nonatomic, readonly) NSInteger newIndex;

- (id)initWithOldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
