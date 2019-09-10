//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import Foundation

class CookieViewModel: CustomStringConvertible {

	// Our cookie model use Int for their IDs, having different type here just for the demo.
	public let id: String
	public private(set) var name: String
	// ... other fields.

	// `true` if we should use a larger cell for this cookie.
	public private(set) var useLargeCell: Bool

	// Using a delegate here instead of observers to keep the example small and independent.
	public weak var delegate: CookieViewModelDelegate?

	init(model: CookieList.Cookie) {
		self.id = "\(model.id)"
		self.name = model.name
		self.useLargeCell = model.isFavorite
		// ...
	}

	@discardableResult
	public func update(model: CookieList.Cookie) -> Bool {

		assert(self.id == "\(model.id)")

		var dirty = false

		if self.name != model.name {
			self.name = model.name
			dirty = true
		}

		let useLargeCell = model.isFavorite
		if self.useLargeCell != useLargeCell {
			self.useLargeCell = useLargeCell
			dirty = true
		}

		// ...

		if dirty {
			delegate?.cookieViewModelDidChange(viewModel: self)
		}
		return dirty
	}

	public var description: String {
		return "\(type(of: self))(#\(id), '\(name)', large: \(useLargeCell))"
	}
}

protocol CookieViewModelDelegate: AnyObject {
	func cookieViewModelDidChange(viewModel: CookieViewModel)
}

