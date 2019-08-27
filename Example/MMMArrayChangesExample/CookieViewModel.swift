//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import Foundation

/// (NSObject because `MMMArrayChanges` is ObjC friendly and thus we need to be too.)
class CookieViewModel: NSObject {

	// Our cookie model use Int for their IDs, having different type here just for the demo.
	public let id: String
	public private(set) var name: String
	// ... other fields.

	// Using a delegate here instead of observers to keep the example small and independent.
	public weak var delegate: CookieViewModelDelegate?

	init(model: CookieList.Cookie) {
		self.id = "\(model.id)"
		self.name = model.name
		// ...
	}

	public func update(model: CookieList.Cookie) {

		assert(self.id == "\(model.id)")

		var dirty = false

		if self.name != model.name {
			self.name = model.name
			dirty = true
		}

		// ...

		if dirty {
			delegate?.cookieViewModelDidChange(viewModel: self)
		}
	}
}

protocol CookieViewModelDelegate: AnyObject {
	func cookieViewModelDidChange(viewModel: CookieViewModel)
}

