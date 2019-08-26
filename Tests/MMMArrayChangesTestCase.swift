//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import XCTest
import MMMArrayChanges

// Let say we have a list of rich (or "thick", as opposed to "anemic" https://martinfowler.com/bliki/AnemicDomainModel.html)
// models for cookies. This is a sketch for a single element of such a "thick" list.
class CookieModel {

	public let id: String

	public private(set) var name: String

	// For a rich model a corresponding plain API-domain object is just a single item among other things.
	internal init(
		apiModel: CookieFromAPI
	) {
		self.id = "\(apiModel.id)"
		self.name = apiModel.name
		// ... more things here, like the parent list of cookies objects which knows about favorite cookies, etc.
	}

	// When we get a list of fresh cookies from the backend there should be a way to update our "thick" models without
	// recreating it and requiring observers to resubscribe.
	internal func update(apiModel: CookieFromAPI) {
		assert(self.id == "\(apiModel.id)", "It has to be a matching object from the API domain")
		self.name = apiModel.name
		// ... other fields.
		// ... calls observers only if any fields have changed here.
	}

	// ... there can be more than one way of updating this model.

	// In the actual app this kind of model would allow to be observed, so when the name of the cookie is edited
	// on the backend, for example, then somebody could get a change by observing a single cookie object:

	public func addObserver(_ observer: CookieModelObserver) {}
	public func removeObserver(_ observer: CookieModelObserver) {}

	// The actual app would also provide more information on this model by cross-referencing other objects,
	// e.g. `FavoriteCookies`:

	public var isFavorite: Bool {
		// return parentCookieList.favoriteCookies.contains(self.id).
		return false
	}

	// It's useful sometimes to mark a model as deleted/detached as somebody still might have a reference to it after
	// it's gone from the main list (like a view somewhere forgotten to be hidden or being animated out of the screen).
	public private(set) var isRemoved: Bool = false

	public func markAsRemoved() {
		assert(!isRemoved)
		isRemoved = true
		// ... notify observers.
	}
}

protocol CookieModelObserver {
	func cookieDidChange()
}

// And this is something plain and simple from the "API domain".
struct CookieFromAPI {
	let id: Int
	let name: String
}

class MMMArrayChangesTestCaseSwift : XCTestCase {

	func testDiffMapBasics() {

		// Imagine we are somewhere in a "thick" model representing a list of cookies.
		var items: [CookieModel] = []

		// And we've got our first ever update from the backend.
		let apiResponse: [CookieFromAPI] = [
			CookieFromAPI(id: 1, name: "Almond biscuit"),
			CookieFromAPI(id: 2, name: "Animal cracker")
		]

		// We could simply recreate all our items and notify our observers (i.e. observers of the list itself).
		items = apiResponse.map { (plainCookie) -> CookieModel in
			return CookieModel(apiModel: plainCookie)
		}

		// ... notify observers about the whole list updated.

		// However if (almost) nothing has changed in the list, then it would be nicer (performance-wise and very often
		// visually), to nofity only the observers of updated cookies, like "Almond biscuit"'s in this case,
		// however using our simple map() would recreate the whole list.
		let apiResponse2: [CookieFromAPI] = [
			CookieFromAPI(id: 1, name: "Almond cookie"),
			CookieFromAPI(id: 2, name: "Animal cracker")
		]

		let updatedCookie = items[0] // Just to compare below

		// So let's use diffMap() (in a function to reuse in this test):
		self.diffMap(items: &items, apiResponse: apiResponse2)

		XCTAssert(items[0] === updatedCookie, "The object reference is supposed to stay the same")
		XCTAssert(items[0].name == "Almond cookie", "While properties should update")
	}

	func diffMap(items: inout [CookieModel], apiResponse: [CookieFromAPI]) {
		items = items.diffMap(
			// We need to tell it how to match elements in the current and source arrays by providing IDs that can be compared.
			elementId: { cookie -> String in cookie.id },
			sourceArray: apiResponse,
			// We decided to use the same IDs that are used by the models, i.e. string ones.
			sourceElementId: { plainCookie -> String in "\(plainCookie.id)" },
			added: { (apiModel) -> CookieModel in
				// Called for every plain API object that has no corresponding "thick" cookie model yet,
				// i.e. for every new cookie. We create new "thick" models only for those.
				return CookieModel(apiModel: apiModel)
			},
			updated: { (cookie, apiCookie) in
				// Called for every cookie model that still has a corresponding plain object in the API response.
				// Let's update the fields we are interested in and notify observers only when needed.
				cookie.update(apiModel: apiCookie)
			},
			removed: { (cookie) in
				// Called for all cookies that don't have matching plain objects in the backend response.
				// Let's just mark them as removed just in case somebody holds a reference to them a bit longer than
				// needed and might appreciate knowing that the object they hold is not in the main list anymore.
				cookie.markAsRemoved()
			}
		)
	}
}
