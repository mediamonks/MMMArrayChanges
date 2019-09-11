//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

/**
Finds the differences between two arrays with elements possibly of different types.

(`MMMArrayChanges` ported from ObjC for better performance and convenience. The ObjC version was unable to directly
work with arrays of Swift protocols among other things.)

This is to help with detection of changes in a collection of items in general and in particular to have these changes
compatible with expectations of `UITableView`.

A typical use case is when we sync a list of items with a backend periodically and want to properly animate all
the changes in the table view using batch updates.

Note that in order to remain compatible with `UITableView` the indexes for removals and the source indexes
for moves are always relative to the old array without any changes perfomed on it yet, while the target indexes
for moves and the indexes of insertions are relative to the new array.
*/
public class MMMArrayChanges: CustomStringConvertible, Equatable {

	public struct Removal: CustomStringConvertible, Equatable {

		/// The index of the object being removed in the *old* array.
		public let index: Int

		public init(_ index: Int) {
			self.index = index
		}

		public var description: String {
			return "-\(index)"
		}
	}

	public struct Insertion: CustomStringConvertible, Equatable {

		/// The index of the inserted object in the *new* array.
		public let index: Int

		public init(_ index: Int) {
			self.index = index
		}

		public var description: String {
			return "+\(index)"
		}
	}

	public struct Move: CustomStringConvertible, Equatable {

		/// The index of the object being moved in the *old* array.
		public let oldIndex: Int

		/// The index of the object being moved in the *new* array.
		public let newIndex: Int

		/// These are not needed for the table view, but handy when need to replay the changes on a normal array.
		/// An intermediate array is the old one after all the removals applied but before any insertions are made.
		/// The indexes also take into account moves performed before the current one.
		let intermediateSourceIndex: Int
		let intermediateTargetIndex: Int

		public init(_ oldIndex: Int, _ newIndex: Int, _ intermediateSourceIndex: Int, _ intermediateTargetIndex: Int) {
			self.oldIndex = oldIndex
			self.newIndex = newIndex
			self.intermediateSourceIndex = intermediateSourceIndex
			self.intermediateTargetIndex = intermediateTargetIndex
		}

		public var description: String {
			return "\(oldIndex) -> \(newIndex)"
		}
	}

	public struct Update: CustomStringConvertible, Equatable {

		/// The index of the changed object in the *old* array.
		public let oldIndex: Int

		/// The index of the changed object in the *new* array.
		public let newIndex: Int

		public init(_ oldIndex: Int, _ newIndex: Int) {
			self.oldIndex = oldIndex
			self.newIndex = newIndex
		}

		public var description: String {
			return "\(oldIndex)/\(newIndex)"
		}
	}

	public let removals: [Removal]
	public let insertions: [Insertion]
	public let moves: [Move]
	public let updates: [Update]

	public init(removals: [Removal], insertions: [Insertion], moves: [Move], updates: [Update]) {
		self.removals = removals
		self.insertions = insertions
		self.moves = moves
		self.updates = updates
	}

	/// True if the receiver represents "no changes" situation.
	public var isEmpty: Bool {
		return removals.isEmpty && insertions.isEmpty && moves.isEmpty && updates.isEmpty
	}

	// This and related Equatables are for unit-testing only.
	public static func == (a: MMMArrayChanges, b: MMMArrayChanges) -> Bool {
		return a.removals == b.removals
			&& a.insertions == b.insertions
			&& a.moves == b.moves
			&& a.updates == b.updates
	}

	public var description: String {

		var changes: [CustomStringConvertible] = []
		changes.append(contentsOf: removals)
		changes.append(contentsOf: insertions)
		changes.append(contentsOf: moves)
		changes.append(contentsOf: updates)

		var result = ""
		changes.forEach {
			if !result.isEmpty {
				result.append(", ")
			}
			result.append(String(describing: $0))
		}

		return "\(String(describing: type(of: self)))(\(result))"
	}

    /**
	Replays the changes represented by the receiver onto the given array (which in general is different from the array
	that was used to record the changes).

	The order of closures in the parameters reflects the order of operations:

	1. Items corresponding to records in `removals` are deleted with the `remove` closure called after every removal.
	2. Items are moved according to `moves` records.
	3. New items are inserted with `transform` closure making items for the array from items of the `sourceArray`.
	4. Old items are updated from the new ones by the `update` closure.

	- Parameters:

		- array: The array we're replaying changes onto.

		- sourceArray: The array we want our target array to correspond to after the application of the changes.
			(Note this one might have objects of different type.)

		- remove: Called for every item removed from the array (after removal but before items are moved).

		- transform: Creates a new element to be inserted into our array from a corresponding element of the `sourceArray`.

		- update: Updates the given element from a target array based on the corresponding element from the `sourceArray`.
	*/
    public func applyToArray<Element, SourceElement>(
    	_ array: inout [Element],
    	sourceArray: [SourceElement],
    	remove: ((_ element: Element) -> Void),
    	transform: (_ newElement: SourceElement) -> Element,
    	update: ((_ element: Element, _ sourceElement: SourceElement) -> Void)
	) {

		for r in removals {
			let item = array[r.index]
			array.remove(at: r.index)
			remove(item)
		}

		for m in moves {
			let item = array[m.intermediateSourceIndex]
			array.remove(at: m.intermediateSourceIndex)
			array.insert(item, at: m.intermediateTargetIndex)
		}

		for i in insertions {
			let item = transform(sourceArray[i.index])
			array.insert(item, at: i.index)
		}

		for u in updates {
			update(array[u.newIndex], sourceArray[u.newIndex])
		}
	}

	/**
	Replays the changes represented by the receiver onto a `UITableView` within a `beginUpdates()`/`endUpdates()` block.

	Only the changes corresponding to `removals`, `insertions` and `moves` are replayed.
	The ones corresponding to the `updates` should be replayed as row reloads in a separate call because:

	1. They are not needed when cells observe the corresponding view models on their own and their heights don't change.
	2. Reloads cannot belong to the same `beginUpdates()`/`endUpdates()` transaction as cells that move cannot be
	   reloaded as well (getting "attempt to perform a delete and a move from the same index path").
	3. Replaying the reloads in a separate `beginUpdates()`/`endUpdates()` block just after the insertions/removals
	   won't lead to nice results anyway, one have to wait for the previous animations to complete.

	- Returns:

		- `true`, if at least one change has been applied.

	- Parameters:
	
		- indexPathForItemIndex: A closure returning an index path corresponding to the index of the element
			either in the new or the old arrays. I.e. it can only customize the section or provide fixed shift
			of row indexes.
	*/
	@discardableResult
	public func applySkippingReloads(
		tableView: UITableView,
		indexPathForItemIndex: (_ itemIndex: Int) -> IndexPath,
		deletionAnimation: UITableView.RowAnimation,
		insertionAnimation: UITableView.RowAnimation
	) -> Bool {

		guard removals.count + insertions.count + moves.count > 0 else {
			return false
		}

		tableView.beginUpdates()

		tableView.deleteRows(at: removals.map { indexPathForItemIndex($0.index) }, with: deletionAnimation)
		tableView.insertRows(at: insertions.map { indexPathForItemIndex($0.index) }, with: insertionAnimation)

		moves.forEach {
			tableView.moveRow(at: indexPathForItemIndex($0.oldIndex), to: indexPathForItemIndex($0.newIndex))
		}

		tableView.endUpdates()

		return true
	}

	/**
	Applies the changes corresponding to `updates` property of the receiver as row reloads on the given table view
	within a `beginUpdates()`/`endUpdates()` block. It is assumed that other changes represented by the receiver
	have been applied already, i.e. this function works with `newIndex` property of every record in `updates`.

	This is needed for better cell update animations when reloads should happen at the same time as movements/removals/insertions.
	*/
	@discardableResult
	public func applyReloadsAfter(
		tableView: UITableView,
		indexPathForItemIndex: (_ itemIndex: Int) -> IndexPath,
		reloadAnimation: UITableView.RowAnimation
	) -> Bool {

		guard updates.count > 0 else {
			return false
		}

		tableView.beginUpdates()
		tableView.reloadRows(at: updates.map { indexPathForItemIndex($0.newIndex) }, with: reloadAnimation)
		tableView.endUpdates()

		return true
	}

	/**
	Same as `applyReloadsAfter(tableView:indexPathForItemIndex:reloadAnimation:)` but assuming that other changes represented
	by the receiver have **not** been applied already, i.e. this function works with `oldIndex` property of every record in `updates`.
	*/
	@discardableResult
	public func applyReloadsBefore(
		tableView: UITableView,
		indexPathForItemIndex: (_ itemIndex: Int) -> IndexPath,
		reloadAnimation: UITableView.RowAnimation
	) -> Bool {

		guard updates.count > 0 else {
			return false
		}

		tableView.beginUpdates()
		tableView.reloadRows(at: updates.map { indexPathForItemIndex($0.oldIndex) }, with: reloadAnimation)
		tableView.endUpdates()

		return true
	}

	/**
	Finds UITableView-compatible differences between two arrays consisting of elements of different types
	updating the given array along the way while avoiding recreating elements that have corresponding elements
	in the `sourceArray`.

	The `elementId` and `sourceElementId` closures should be able to provide an ID that can be used to distiniguish
	elements of the old and new arrays.

	- Parameters:

		- update: Optional closure that's called for every element in the array that was not added to update its contents.

		- remove: Optional closure that's called for every removed element of the array.
			Note that it should not try removing the corresponing element, it's only for your own book-keeping.

		- transform: A closure that should be able to creat a new element of the array from the corresponding element
			of the source array.
	*/
	public static func byUpdatingArray<Element, SourceElement, ElementId: Hashable>(
		_ array: inout [Element], elementId: (Element) -> ElementId,
		sourceArray: [SourceElement], sourceElementId: (SourceElement) -> ElementId,
		update: ((_ element: Element, _ oldIndex: Int, _ sourceElement: SourceElement, _ newIndex: Int) -> Bool)? = nil,
		remove: ((_ element: Element, _ oldIndex: Int) -> Void)? = nil,
		transform: (_ newElement: SourceElement, _ newIndex: Int) -> Element
	) -> MMMArrayChanges {

		// First let's quickly check if the arrays are the same, this should be the most common situation.
		if array.count == sourceArray.count {

			// Yes, it's like zip().allSatisty().
			let sameIds: Bool = {
				for i in 0..<array.count {
					if elementId(array[i]) != sourceElementId(sourceArray[i]) {
						return false
					}
				}
				return true
			}()
			if sameIds {

				// OK, nothing was moved, added or removed.
				// But let's check for item updates.
				var updates: [Update] = []
				for i in 0..<array.count {
					if update?(array[i], i, sourceArray[i], i) ?? false {
						updates.append(.init(i, i))
					}
				}

				return MMMArrayChanges(removals: [], insertions: [], moves: [], updates: updates)
			}
		}

		// OK, there seem to be changes, let's index all the items by their IDs.

		// TODO: Not sure about complexity of creation of these sets, O(N * log(N))?

		// All IDs from the `oldArray`.
		let oldIds = Set<ElementId>.init(array.map(elementId))
		precondition(oldIds.count == array.count, "Elements in the `oldArray` cannot have duplicate IDs")

		// All IDs from the `newArray`.
		let newIds = Set<ElementId>(sourceArray.map(sourceElementId))
		precondition(newIds.count == sourceArray.count, "Elements in the `newArray` cannot have duplicate IDs")

		// Removals.
		var removals: [Removal] = []
		// intermediate[i] tells where the i-th element was in the `oldArray` before elements to be removed were gone.
		var intermediate = [Int](0..<array.count)
		// Removing in the reverse order, so no correction is needed for the indexes.
		for i in (0..<array.count).reversed() {
			if !newIds.contains(elementId(array[i])) {
				removals.append(.init(i))
				intermediate.remove(at: i)
			}
		}

		// Insertions.
		var insertions: [Insertion] = []
		for i in 0..<sourceArray.count {
			if !oldIds.contains(sourceElementId(sourceArray[i])) {
				insertions.append(.init(i))
			}
		}

		// Moves and updates.
		var moves: [Move] = []
		var updates: [Update] = []

		// Going through the new array and checking where each element has moved from.
		var intermediateTargetIndex: Int = 0
		for newIndex in 0..<sourceArray.count {

			let newItem = sourceArray[newIndex]
			let newId = sourceElementId(newItem)
			if !oldIds.contains(newId) {
				// This one was just inserted, not interested.
				continue
			}

			let oldIndex = intermediate[intermediateTargetIndex]
			let oldItem = array[oldIndex]
			let oldId = elementId(oldItem)
			if oldId == newId {

				// The item is at its target position already, let's only check if the contents has updated.
				if update?(oldItem, oldIndex, newItem, newIndex) ?? false {
					updates.append(.init(oldIndex, newIndex))
				}

			} else {

				// A different element here, let's see where it's coming from.

				// Let's find where this element is in the old array.
				// TODO: same as in ObjC, this reverse look up needs to be improved performance-wise.
				var oldNewIndex: Int = NSNotFound
				var intermediateSourceIndex: Int = 0
				while intermediateSourceIndex < intermediate.count {
					oldNewIndex = intermediate[intermediateSourceIndex]
					if elementId(array[oldNewIndex]) == newId {
						break
					}
					intermediateSourceIndex += 1
				}
				precondition(oldNewIndex != NSNotFound && intermediateSourceIndex < intermediate.count)

				// Record a move first.
				moves.append(.init(oldNewIndex, newIndex, intermediateSourceIndex, intermediateTargetIndex))

				// Then update the intermediate array accordingly.
				let t = intermediate[intermediateSourceIndex]
				intermediate.remove(at: intermediateSourceIndex)
				intermediate.insert(t, at: intermediateTargetIndex)

				// And finally check if the item has content changes as well.
				if update?(array[oldNewIndex], oldNewIndex, newItem, newIndex) ?? false {
					// Yes, record an update, too.
					updates.append(.init(oldNewIndex, newIndex))
				}
			}

			intermediateTargetIndex += 1
		}

		for r in removals {
			let item = array[r.index]
			array.remove(at: r.index)
			remove?(item, r.index)
		}

		for m in moves {
			let item = array[m.intermediateSourceIndex]
			array.remove(at: m.intermediateSourceIndex)
			array.insert(item, at: m.intermediateTargetIndex)
		}

		for i in insertions {
			let item = transform(sourceArray[i.index], i.index)
			array.insert(item, at: i.index)
		}

		return MMMArrayChanges(removals: removals, insertions: insertions, moves: moves, updates: updates)
	}

	/// A shortcut for the case when both arrays contain objects of reference types and their references can be used as identifiers.
	public static func byUpdatingArray<Element: AnyObject>(
		_ array: inout [Element],
		sourceArray: [Element],
		update: ((_ element: Element, _ oldIndex: Int, _ sourceElement: Element, _ newIndex: Int) -> Bool)? = nil,
		remove: ((_ element: Element, _ oldIndex: Int) -> Void)? = nil
	) -> MMMArrayChanges {
		let result = byUpdatingArray(
			&array,
			elementId: { (element: Element) -> ObjectIdentifier in
				return ObjectIdentifier(element)
			},
			sourceArray: sourceArray,
			sourceElementId: { (sourceElement: Element) -> ObjectIdentifier in
				return ObjectIdentifier(sourceElement)
			},
			update: update,
			remove: remove,
			transform: { (sourceElement: Element, newIndex: Int) -> Element in
				return sourceElement
			}
		)
		return result
	}

	/// Changes between two simple arrays consisting of the same hashable value types, so elements themselves can
	/// be used as their own identifiers.
	/// (This is mainly used for testing the receiver using arrays of Int.)
	public static func betweenSimpleArrays<Element: Hashable>(oldArray: [Element], newArray: [Element]) -> MMMArrayChanges  {
		var tempArray = oldArray
		let result = byUpdatingArray(
			&tempArray,
			elementId: { (_ element: Element) -> Element in
				return element
			},
			sourceArray: newArray,
			sourceElementId: { (_ sourceElement: Element) -> Element in
				return sourceElement
			},
			update: { (element, oldIndex, sourceElement, newIndex) -> Bool in
				return false
			},
			remove: { (element, oldIndex) -> Void in
			},
			transform: { (newElement, newIndex) -> Element in
				return newElement
			}
		)
		return result
	}
}
