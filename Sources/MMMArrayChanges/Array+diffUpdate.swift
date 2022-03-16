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

	- Complexity:

		Must be *O(n^2)* because removing elements from a dictionary is quoted at *O(n)*.
	*/
	@discardableResult
	public mutating func diffUpdate<SourceElement, ElementId: Hashable>(
		elementId: (_ element: Element) -> ElementId,
		sourceArray: [SourceElement], sourceElementId: (_ sourceElement: SourceElement) -> ElementId,
		transform: (_ sourceElement: SourceElement) -> Element,
		update: ((_ element: Element, _ sourceElement: SourceElement) -> Bool)? = nil,
		remove: ((_ element: Element) -> Void)? = nil
	) -> Bool {
		// We just use the compact logic here, since that will behave the same with a
		// non-optional transform closure.
		return compactDiffUpdate(
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
		update: ((_ element: Element, _ sourceElement: SourceElement) -> Bool)? = nil,
		remove: ((_ element: Element) -> Void)? = nil
	) -> Bool {

		var changed = false

		// First building an index of the existing elements, i.e. ID -> Element.
		var elementById = [ElementId: Element](uniqueKeysWithValues: self.map { (elementId($0), $0) })

		let result = sourceArray.compactMap { (sourceElement) -> Element? in
			let id = sourceElementId(sourceElement)
			if let element = elementById[id] {
				// According to our index the current array already has a matching element, so just keep it...
				elementById.removeValue(forKey: id)
				// ...possibly updating.
				if update?(element, sourceElement) ?? false {
					// The update closure indicated that a change in the existing element should be counted
					// alongside with removals, additions and moves.
					changed = true
				}
				return element
			} else {
				// There is no matching element in the current array, let's create it at
				// this position as long as it transforms.
				if let el = transform(sourceElement) {
					changed = true
					return el
				}
				return nil
			}
		}

		// Leftovers in the index mean removed elements and thus that the array had changes.
		if !elementById.isEmpty {
			changed = true
		}

		if !changed {
			// Seems like no additions or removals, but it's possible that the order of elements has changed.
			assert(self.count == result.count)
			for i in 0..<self.count {
				if elementId(self[i]) != elementId(result[i]) {
					// Right, something is off, report the change and most importantly update the current array.
					changed = true
					break
				}
			}
		}

		if changed {

			self = result

			// IDs left in the index correspond to elements missing in the new array, so they have to me marked as gone.
			if let remove = remove {
				elementById.forEach { (_, element) in
					remove(element)
				}
			}
		}

		return changed
	}
}
