//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

/// Represents differences between two arrays with elements possibly of different types.
///
/// (`MMMArrayChanges` ported from ObjC for better performance and convenience. The ObjC version was unable to directly
/// work with arrays of Swift protocols among other things.)
///
/// This is to help with detection of changes in a collection of items in general and in particular to have these changes
/// compatible with expectations of `UITableView`.
///
/// A typical use case is when we sync a list of items with a backend periodically and want to properly animate all
/// the changes in the table view using batch updates.
///
/// Note that in order to remain compatible with `UITableView` the indexes for removals and the source indexes
/// for moves are always relative to the old array without any changes perfomed on it yet, while the target indexes
/// for moves and the indexes of insertions are relative to the new array.
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
			return "\(oldIndex) -> *\(newIndex)"
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
	Applies the difference between two arrays recorded earlier.

	- Parameters:

	  - oldArray: The array the changes were built with.

	  - newArray: The array the changes were built with.

	  - transform: Creates a new element to be inserted into `oldArray` from a corresponding element of the `newArray`.

	  - update: Modifies an element from the `oldArray` based on the corresponding element from the `newArray`.

	  - remove: Optional closure that is called for every item removed from the `oldArray` (after the removal
	    but before adding new items or moving them).
     */
    public func applyToArray<OldElement, NewElement>(
    	_ oldArray: inout [OldElement],
    	newArray: [NewElement],
    	transform: (NewElement) -> OldElement,
    	update: ((OldElement, NewElement) -> Void)? = nil,
    	remove: ((OldElement) -> Void)? = nil
	) {

		for r in removals {
			let item = oldArray[r.index]
			oldArray.remove(at: r.index)
			remove?(item)
		}

		for m in moves {
			let item = oldArray[m.intermediateSourceIndex]
			oldArray.remove(at: m.intermediateSourceIndex)
			oldArray.insert(item, at: m.intermediateTargetIndex)
		}

		for i in insertions {
			let item = transform(newArray[i.index])
			oldArray.insert(item, at: i.index)
		}

		if let update = update {
			for u in updates {
				update(oldArray[u.newIndex], newArray[u.newIndex])
			}
		}
	}

	/**
		Replays updates represented by the receiver onto a `UITableView` within its own beginUpdates()/endUpdates() block.

		Updates without actual movements (i.e. where old and new indexes are the same) are applied as row reloads
		only when `reloadAnimation` is non-`nil` because:

		1) The refresh of the contents of cells is normally handled by the cells themeselves observing
		the corresponding view models and an extra reload would be more expensive in this case and probably visually
		worse.

		2) UITableView does not seem to be hadling well reloads within the same beginUpdate()/endUpdate() block.

		The index paths of such 'updated' but not moved cells are returned so you could still reload them if needed
		(one case would be if your updated cells might change their height).

		- Parameters:
			- indexPathForItemIndex: A block that can return an index path corresponding to the index of the element
				either in the new or the old arrays. I.e. it can only customize the section or provide fixed shift
				of the row index.
			- reloadAnimation: If non-nil, then updates without movemenet are applied as row reloads within
				a separate beginUpdates()/endUpdates() block.

	*/
	public func applyToTableView(
		_ tableView: UITableView,
		indexPathForItemIndex: (Int) -> IndexPath,
		deletionAnimation: UITableView.RowAnimation,
		insertionAnimation: UITableView.RowAnimation,
		reloadAnimation: UITableView.RowAnimation? = nil
	) {
		if isEmpty {
			return
		}

		tableView.beginUpdates()

		tableView.deleteRows(at: removals.map { indexPathForItemIndex($0.index) }, with: deletionAnimation)
		tableView.insertRows(at: insertions.map { indexPathForItemIndex($0.index) }, with: insertionAnimation)

		updates.forEach {
			if $0.oldIndex != $0.newIndex {
				tableView.moveRow(at: indexPathForItemIndex($0.oldIndex), to: indexPathForItemIndex($0.newIndex))
			}
		}

		tableView.endUpdates()

		if let reloadAnimation = reloadAnimation {
			tableView.reloadRows(
				at: updates.filter { $0.oldIndex == $0.newIndex }.map{ indexPathForItemIndex($0.oldIndex) },
				with: reloadAnimation
			)
		}
	}
}

extension MMMArrayChanges {

	public convenience init<OldElement, NewElement, ElementId: Hashable>(
		oldArray: [OldElement], oldElementId: (OldElement) -> ElementId,
		newArray: [NewElement], newElementId: (NewElement) -> ElementId,
		hasUpdatedContents: ((OldElement, NewElement) -> Bool)? = nil
	) {
		// TODO: it's a literal port from ObjC below, perhaps can improve this.

		// First let's quickly check if the arrays are the same, this should be the most common situation.
		if oldArray.count == newArray.count {

			let sameIds: Bool = {
				// Yes, it's like zip().allSatisty().
				for i in 0..<oldArray.count {
					if oldElementId(oldArray[i]) != newElementId(newArray[i]) {
						return false
					}
				}
				return true
			}()

			if sameIds {

				// OK, nothing was moved, added or removed.
				// But let's check if the contents of any of the items have changed.
				var updates: [Update] = []
				if let hasUpdatedContents = hasUpdatedContents {
					for i in 0..<oldArray.count {
						if hasUpdatedContents(oldArray[i], newArray[i]) {
							updates.append(.init(i, i))
						}
					}
				} else {
					// Assuming no changes in the contents when the comparison closure is not provided.
				}
				self.init(removals: [], insertions: [], moves: [], updates: updates)

				return
			}
		}

		// Now let's index all the items by their IDs.

		// All IDs from the `oldArray`.
		let oldIds = Set<ElementId>(oldArray.map(oldElementId))
		precondition(oldIds.count == oldArray.count, "Elements in the `oldArray` cannot have duplicate IDs")

		// All IDs from the `newArray`.
		let newIds = Set<ElementId>(newArray.map(newElementId))
		precondition(newIds.count == newArray.count, "Elements in the `newArray` cannot have duplicate IDs")

		// Removals.
		var removals: [Removal] = []
		// intermediate[i] will be an index of the object in the oldArray at i-th place after all removals are performed.
		var intermediate = [Int](0..<oldArray.count)
		// Removing in the reverse order, so no correction is needed for the indexes.
		for i in (0..<oldArray.count).reversed() {
			if !newIds.contains(oldElementId(oldArray[i])) {
				removals.append(.init(i))
				intermediate.remove(at: i)
			}
		}

		// Insertions.
		var insertions: [Insertion] = []
		for i in 0..<newArray.count {
			if !oldIds.contains(newElementId(newArray[i])) {
				insertions.append(.init(i))
			}
		}

		// Moves and updates.
		var moves: [Move] = []
		var updates: [Update] = []

		var intermediateTargetIndex: Int = 0
		for newIndex in 0..<newArray.count {

			let newItem = newArray[newIndex]
			let newId = newElementId(newItem)
			if !oldIds.contains(newId) {
				// Skip added items.
				continue
			}

			let oldIndex = intermediate[intermediateTargetIndex]
			let oldItem = oldArray[oldIndex]
			let oldId = oldElementId(oldItem)
			if oldId == newId {

				// The item is at its target position already, let's only check if the contents has updated.
				if hasUpdatedContents?(oldItem, newItem) ?? false {
					updates.append(.init(oldIndex, newIndex))
				}

			} else {

				// A different element here, need a movement.

				// Let's find where this element is in the old array.
				// TODO: same as in ObjC, this reverse look up needs to be improved using ID to index map
				var oldNewIndex: Int = NSNotFound
				var intermediateSourceIndex: Int = 0
				while intermediateSourceIndex < intermediate.count {
					oldNewIndex = intermediate[intermediateSourceIndex]
					if oldElementId(oldArray[oldNewIndex]) == newId {
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
				if hasUpdatedContents?(oldArray[oldNewIndex], newItem) ?? false {
					// Yes, record an update, too.
					updates.append(.init(oldNewIndex, newIndex))
				}
			}

			intermediateTargetIndex += 1
		}

		self.init(removals: removals, insertions: insertions, moves: moves, updates: updates)
	}
}

extension MMMArrayChanges {

	/// Simplified initializer for the case when elements of both arrays have same types and can work as their own IDs.
	///
	/// TODO: Later add another one for elements supporting `Identifiable` protocol.
	public convenience init<Element: Hashable>(oldArray: [Element], newArray: [Element]) {
		self.init(
			oldArray: oldArray, oldElementId: { $0 },
			newArray: newArray, newElementId: { $0 }
		)
	}
}

extension MMMArrayChanges {

	/// Simplified initializer for the case when elements of both arrays have same reference types
	/// i.e. `ObjectIdentifier` works well as their ID.
	///
	/// TODO: Later add another one for elements supporting `Identifiable` protocol.
	public convenience init<Element: AnyObject>(oldArray: [Element], newArray: [Element]) {
		self.init(
			oldArray: oldArray, oldElementId: { ObjectIdentifier($0) },
			newArray: newArray, newElementId: { ObjectIdentifier($0) }
		)
	}
}
