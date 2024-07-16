//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import Foundation

extension Array {

	/**

	Updates the receiver so it consists only of transformed elements from another array,
	avoiding transformations for the elements that are already in the receiver.

	This is similar to updating an existing array using `map()`:

		array = sourceArray.map { /* transformation */ }

	where transformation performed only for the elements of `sourceArray` that have no corresponding elements
	in the `array` ("new" or "added"), or, in other words, with transformation skipped for the elements already
	having their transformed versions in the `array`.

	(This is a simplified version of `MMMArrayChanges` that finds the differences and applies them directly
	to the given array. Use this unless you need to record the changes and/or apply them to `UITableView`.)

	---

	For example, let say we maintain an array of "fat" view models that we want to update whenever the corresponding
	models change. We could go with a simple `map()` call, but then we would need to create our "fat" objects again
	even when only some of their properties have been updated (or have not updated at all). Those "fat" view models
	could be also referenced from views observing them and simply changing a couple of properties and notifying the
	observers would be faster and more convenient.

	- Parameters:

		- elementId: Should provide an identifier for any element of the receiver.
		The identifier has to be compatible with the one returned by `sourceElementId` closure.

		- sourceArray: As it says on the tin.

		- sourceElementId: Should provide an identifier for every element of the `sourceArray`.
		The identifier has to be compatible with the one returned by `elementId`.

		- transform: Called to transforms every element of the `sourceArray` that has no corresponding element in
		the receiver yet.

		- update: Called for every element in the receiver that has a corresponding element in the `sourceArray`
		to update the properties of this element.

		Can optionally return `true` to indicate the the corresponding element has been actually changed.
		This will contribute to the result returned by the method.

		- remove: Called for every element of the receiver that does not have a corresponding element in the `sourceArray`.

	- Returns:
		`true`, if the array has changed, i.e. if elements were added or removed or `update` closure
		returned `true` for at least one element.
	*/
	@discardableResult
	public mutating func diffUpdate<SourceElement, ElementId: Hashable>(
		elementId: (_ element: Element) -> ElementId,
		sourceArray: [SourceElement], sourceElementId: (_ sourceElement: SourceElement) -> ElementId,
		transform: (_ sourceElement: SourceElement) -> Element,
		update: ((_ element: Element, _ sourceElement: SourceElement) -> Bool),
		remove: ((_ element: Element) -> Void)
	) -> Bool {
		// We just use the compact logic here, since that will behave the same with a
		// non-optional transform closure.
		compactDiffUpdate(
			elementId: elementId,
			sourceArray: sourceArray,
			sourceElementId: sourceElementId,
			transform: transform,
			update: update,
			remove: remove
		)
	}

	@discardableResult
	/// The same as ``diffUpdate(elementId:sourceArray:transform:update:remove)`` except that it
	/// behaves as a `Array.compactMap` instead of `Array.map`, for cases where your source array can contain
	/// incomplete objects that might be populated in a future call.
	public mutating func compactDiffUpdate<SourceElement, ElementId: Hashable>(
		elementId: (_ element: Element) -> ElementId,
		sourceArray: [SourceElement], sourceElementId: (_ sourceElement: SourceElement) -> ElementId,
		transform: (_ sourceElement: SourceElement) -> Element?,
		update: ((_ element: Element, _ sourceElement: SourceElement) -> Bool),
		remove: ((_ element: Element) -> Void)
	) -> Bool {

		// We don't officially support duplicate IDs, but it's still useful to remove them from the source in the field.
		func uniquedSourceArray() -> [SourceElement] {
			var seen = Set<ElementId>()
			return sourceArray.compactMap { sourceElement -> SourceElement? in
				let id = sourceElementId(sourceElement)
				if seen.contains(id) {
					return nil
				} else {
					seen.insert(id)
					return sourceElement
				}
			}
		}

		// Special cases are fairly common and should be worth handling.
		if self.isEmpty {
			self = uniquedSourceArray().compactMap(transform)
			return !self.isEmpty
		} else if sourceArray.isEmpty {
			self.forEach(remove)
			self = []
			return true
		} else if self.count == sourceArray.count && self.lazy.map(elementId) == sourceArray.lazy.compactMap(sourceElementId) {
			var changed = false
			for (old, new) in zip(self.lazy, sourceArray.lazy) {
				if update(old, new) {
					changed = true
				}
			}
			return changed
		}

		// Let's build an index of the existing elements, i.e. ID -> Element.
		var elementById = [ElementId: Element?].init(
			self.map { (elementId($0), $0) },
			// Again, we don't officially support non-unique IDs, but we'd rather not crash.
			uniquingKeysWith: { first, _ in first }
		)

		var changed = false
		let sourceArray = uniquedSourceArray()

		let result = sourceArray.compactMap { sourceElement -> Element? in
			let id = sourceElementId(sourceElement)
			switch elementById[id] {
			case .some(let element?):
				// The current array already has a matching element, so just keep it and update.
				if update(element, sourceElement) {
					// The update closure indicated that a change in the existing element should be counted
					// alongside with removals, additions and moves.
					changed = true
				}
				// Mark as seen by replacing with a nil (instead of removing), so we can detect duplicates
				// and avoid potential O(*n*) complexity of `removeValue`.
				elementById[id] = .some(.none)
				return element
			case .some(.none):
				// Duplicate ID, filtering out.
				return nil
			case .none:
				// There is no matching element, let's create it at this position as long as it transforms.
				guard let el = transform(sourceElement) else {
					return nil
				}
				changed = true
				return el
			}
		}

		// Leftovers in the index mean removed elements and thus that the array had changes.
		changed = changed || elementById.values.contains { $0 != nil }

		if !changed {
			// No additions or removals, but it's possible that the order of elements has changed.
			assert(self.count == result.count)
			changed = self.lazy.map(elementId) != sourceArray.lazy.compactMap(sourceElementId)
		}

		if changed {
			self = result
			// IDs left in the index correspond to elements missing in the new array, so they have to me marked as gone.
			elementById.values.forEach {
				$0.map(remove)
			}
		}

		return changed
	}
}
