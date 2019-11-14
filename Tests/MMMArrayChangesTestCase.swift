//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import XCTest
import MMMArrayChanges

// Let say we have a list of rich (as opposed to [anemic](https://martinfowler.com/bliki/AnemicDomainModel.html))
// models for cookies. This is a sketch for a single element of such a list.
private class Cookie {

	public let id: String

	public private(set) var name: String

	internal init(
		apiModel: CookieFromAPI
		// ... for a rich model a corresponding plain API-domain object is just a single item among other things here.
	) {
		self.id = "\(apiModel.id)"
		self.name = apiModel.name
		// ... more properties initialized here, like the parent list of cookies which knows about favorites, etc.
	}

	// When we get a list of fresh cookies from the backend there should be a way to update our "thick" models without
	// recreating them and/or requiring their own observers to resubscribe.
	internal func update(apiModel: CookieFromAPI) -> Bool {

		assert(self.id == "\(apiModel.id)", "It has to be a matching object from the API domain")

		var changed = false

		if self.name != apiModel.name {
			self.name = apiModel.name
			changed = true
		}

		// ... other fields.

		// ... notify observers only if changed.

		return changed
	}

	// ... there can be more than one way of updating this model of course.

	// This kind of model would allow itself to be observed, so when the name of the cookie is edited on the backend,
	// for example, then somebody like a corresponding table view cell (or its view model) could get this change
	// by observing a single cookie object:

	public func addObserver(_ observer: CookieModelObserver) {}
	public func removeObserver(_ observer: CookieModelObserver) {}

	// The actual app would also provide more information on this model by cross-referencing other objects,
	// e.g. `FavoriteCookies`:

	public var isFavorite: Bool {
		// return parentCookieList.favoriteCookies.contains(self.id).
		return false
	}

	// It's useful to mark a model as deleted/detached as somebody still might have a reference to it after it's gone
	// from the main list (like a view somewhere being animated out of the screen or forgotten to be hidden).
	public private(set) var isRemoved: Bool = false

	public func markAsRemoved() {
		assert(!isRemoved)
		isRemoved = true
		// ... notify observers.
	}
}

private protocol CookieModelObserver {
	func cookieDidChange(cookie: Cookie)
	// ...
}

// And this is something plain and simple from the "API domain".
private struct CookieFromAPI {
	let id: Int
	let name: String
}

class MMMArrayChangesTestCaseSwift : XCTestCase {

	func testBasics() {
		XCTAssertEqual(
			MMMArrayChanges.betweenSimpleArrays(oldArray: [1, 2, 3], newArray: [3, 4, 2]),
			MMMArrayChanges(
				removals: [.init(0)],
				insertions: [.init(1)],
				moves: [.init(2, 0, 1, 0)],
				updates: []
			)
		)
	}

	func testDiffUpdate() {

		// Imagine we are somewhere in a "thick" model representing a list of cookies.
		var items: [Cookie] = []

		// And we've got our first ever update from the backend.
		let apiResponse: [CookieFromAPI] = [
			CookieFromAPI(id: 1, name: "Almond biscuit"),
			CookieFromAPI(id: 2, name: "Animal cracker")
		]

		// We could simply recreate all our items and notify our observers (i.e. observers of the list itself).
		items = apiResponse.map { (plainCookie) -> Cookie in
			return Cookie(apiModel: plainCookie)
		}

		// ... notify observers about the whole list updated.

		// (Let's grab just for comparison below.)
		let almondCookie = items[0]
		let animalCracker = items[1]

		// However if (almost) nothing has changed in the list, then it would be nicer (performance-wise and very often
		// visually), to nofity only the observers of updated cookies, like "Almond biscuit"'s in this case:
		let apiResponse2: [CookieFromAPI] = [
			CookieFromAPI(id: 1, name: "Almond cookie"),
			CookieFromAPI(id: 2, name: "Animal cracker")
		]

		// Using our simple map() would recreate the whole list however, so let's try diffMap()
		// (which is wrapped into a function here to reuse it later in this test).
		XCTAssertTrue(self.diffUpdate(items: &items, apiResponse: apiResponse2))

		// Note that updating with the same data should not have any effect.
		XCTAssertFalse(self.diffUpdate(items: &items, apiResponse: apiResponse2))

		XCTAssert(items[0] === almondCookie && items[1] === animalCracker, "The object references are supposed to stay the same")
		XCTAssert(items[0].name == "Almond cookie", "While properties might update")

		// OK, let's add/remove elements:
		let apiResponse3: [CookieFromAPI] = [
			CookieFromAPI(id: 2, name: "Animal cracker"),
			CookieFromAPI(id: 3, name: "Oreo")
		]
		XCTAssertTrue(self.diffUpdate(items: &items, apiResponse: apiResponse3))

		XCTAssert(items.count == 2 && almondCookie.isRemoved, "Almond cookie is gone")
		XCTAssert(items[0] === animalCracker, "Animal cracker is exactly the same object")
		XCTAssert(items[1].name == "Oreo", "And there is a new cookie")

		// Let's make sure that the change in order is captured (premature optimization bug in 0.4.0).
		let apiResponse4: [CookieFromAPI] = [
			CookieFromAPI(id: 3, name: "Oreo"),
			CookieFromAPI(id: 2, name: "Animal cracker")
		]
		XCTAssertTrue(self.diffUpdate(items: &items, apiResponse: apiResponse4))
		XCTAssert(items.count == 2)
		XCTAssert(items[0].name == "Oreo")
		XCTAssert(items[1] === animalCracker)
	}

	private func diffUpdate(items: inout [Cookie], apiResponse: [CookieFromAPI]) -> Bool {

		return items.diffUpdate(
			// We need to tell it how to match elements in the current and source arrays by providing IDs that can be compared.
			elementId: { (cookie: Cookie) -> String in
				return cookie.id
			},
			sourceArray: apiResponse,
			// We decided to use the same IDs that are used by the models, i.e. string ones.
			sourceElementId: { plainCookie -> String in "\(plainCookie.id)" },
			transform: { (apiModel) -> Cookie in
				// Called for every plain API object that has no corresponding "thick" cookie model yet,
				// i.e. for every new cookie. We create new "thick" models only for those.
				return Cookie(apiModel: apiModel)
			},
			update: { (cookie, apiCookie) -> Bool in
				// Called for every cookie model that still has a corresponding plain object in the API response.
				// Let's update the fields we are interested in and notify observers of every individual object.
				// Note that we could also return `false` here regardless of the change status of individual
				// elements, so the diffUpdate() call would only return true in case elements were added or removed.
				return cookie.update(apiModel: apiCookie)
			},
			remove: { (cookie: Cookie) in
				// Called for all cookies that don't have matching plain objects in the backend response.
				// Let's just mark them as removed just in case somebody holds a reference to them a bit longer than
				// needed and might appreciate knowing that the object they hold is not in the main list anymore.
				cookie.markAsRemoved()
			}
		)
	}
}
