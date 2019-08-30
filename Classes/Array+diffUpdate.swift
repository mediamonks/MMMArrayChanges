//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

extension Array where Element: AnyObject {

	/**

	Updates the receiver so it consists only of transformed elements from another array,
	avoiding transformations for the elements that are already in the receiver.

	This is similar to updating an existing array using `map()`:

		array = sourceArray.map { /* transformation */ }

	where transformation performed only for the elements of `sourceArray` that have no corresponding elements
	in the `array` ("new" or "added"), or, in other words, with transformation skipped for the elements already
	having their transformed versions in the `array`.

	(This is a Swift-only simplified version of `MMMArrayChanges` that finds the differences and applies them
	directly to the given array. Use this unless you need to record the changes and/or apply them to `UITableView`.)

	---

	For example, let say we maintain an array of "fat" view models that we want to update whenever the corresponding
	models change. We could go with a simple `map()` call, but then we would need to create our "fat" objects again
	even when only some of their properties have been updated (or have not updated at all). Those "fat" view models
	could be also referenced from views observing them and simply changing a couple of properties and notifying the
	observers would be faster and more convenient.

	- Parameters:

	  - elementId: Provides an identifier for any element of the receiver. The identifier has to be compatible
		with the one returned by `sourceElementId`.

	  - sourceArray: -

	  - sourceElementId: Should be able to provide an identifier for every element of the `sourceArray`.
		The identifier has to be compatible with the one returned by `elementId`.

	  - transform: Called to transforms every element of the `sourceArray` that has no corresponding element in the receiver yet.

	  - update: Called for every element in the receiver that has a corresponding element in the `sourceArray`
		to update the properties of this element.

	  - remove: Called for every element of the receiver that does not have a corresponding element in the `sourceArray`.

	- Complexity:
	Must be *O(n^2)* because removing elements from a dictionary is quoted at *O(n)*.
	*/
	public mutating func diffUpdate<SourceElement, ElementId: Hashable>(
		elementId: (Element) -> ElementId,
		newArray: [SourceElement], newElementId: (SourceElement) -> ElementId,
		transform: (SourceElement) -> Element,
		update: ((Element, SourceElement) -> Void)? = nil,
		remove: ((Element) -> Void)? = nil
	) {

		var index = Dictionary<ElementId, Element>(uniqueKeysWithValues: self.map { (elementId($0), $0) })

		let result = newArray.map { (sourceElement) -> Element in
			let id = newElementId(sourceElement)
			if let element = index[id] {
				index.removeValue(forKey: id)
				update?(element, sourceElement)
				return element
			} else {
				return transform(sourceElement)
			}
		}

		self = result

		if let remove = remove {
			index.forEach { (_, element) in
				remove(element)
			}
		}
	}
}
