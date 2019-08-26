//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

// TODO: put Swift refinements for `MMMArrayChanges` here.

extension Array where Element: AnyObject {

	///
	///
	/// (Essentially a Swift version of `MMMArrayChanges` that does not try to generate changes compatible
	/// with `UITableView` nor track movements of the elements.)
	public func diffMap<ElementId: Hashable, SourceElement>(
		elementId: (Element) -> ElementId,
		sourceArray: [SourceElement],
		sourceElementId: (SourceElement) -> ElementId,
		added: (SourceElement) -> Element,
		updated: (Element, SourceElement) -> Void,
		removed: (Element) -> Void
	) -> [Element] {

		var index = Dictionary<ElementId, Element>(uniqueKeysWithValues: self.map { (elementId($0), $0) })

		let result = sourceArray.map { (sourceElement) -> Element in
			let id = sourceElementId(sourceElement)
			if let element = index[id] {
				index.removeValue(forKey: id)
				updated(element, sourceElement)
				return element
			} else {
				return added(sourceElement)
			}
		}

		index.forEach { (_, element) in
			removed(element)
		}

		return result
	}
}
