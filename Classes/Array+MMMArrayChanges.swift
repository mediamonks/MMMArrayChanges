//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

extension Array where Element: AnyObject {

    /**
		Applies the difference between two arrays recorded via `MMMArrayChanges` to the receiver.

		(A Swift version of `MMMArrayChanges.applyToArray`. Defining it on an `Array` instead of `MMMArrayChanges`
		because the latter would not allow to use generic parameters, i.e. would get "Extension of a generic Objective-C
		class cannot access the class's generic parameters at runtime" error in Swift 4.2.)

		- Parameters:

		  - changes: -

		  - newArray: The array the changes were built with. (Keeping `newArray` name to be in line with the
		    corresponding parameter of `MMMArrayChanges`.

		  - transform: Creates a new element of the receiver from a corresponding item of the new array.

     	  - update: Modifies an element of the receiver based on the corresponding item from the new array.

     	  - remove: Optional closure that is called for every item removed after it is removed from the receiver
     	    but before new items are added or moves are made.
     */
    public mutating func apply<NewItemType>(
    	changes: MMMArrayChanges<Element, NewItemType>,
    	newArray: [NewItemType],
    	transform: (NewItemType) -> Element,
    	update: ((Element, NewItemType) -> Void)? = nil,
    	remove: ((Element) -> Void)? = nil
	) {

		for r in changes.removals {
			let item = self[r.index]
			self.remove(at: r.index)
			remove?(item)
		}

		for m in changes.moves {
			let item = self[m.intermediateSourceIndex]
			self.remove(at: m.intermediateSourceIndex)
			self.insert(item, at: m.intermediateTargetIndex)
		}

		for i in changes.insertions {
			let item = transform(newArray[i.index])
			self.insert(item, at: i.index)
		}

		if let update = update {
			for u in changes.updates {
				update(self[u.newIndex], newArray[u.newIndex])
			}
		}
	}
}

extension Array where Element: AnyObject {

	/**
	Updates the receiver so it consists only of transformed elements from another array,
	avoiding transformations for the elements that are already in the receiver along the way.

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
