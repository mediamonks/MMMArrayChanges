# MMMArrayChanges

iOS library that helps finding (UITableView-compatible) differences between two lists, possibly of different types.

(This is a part of `MMMTemple` suite of iOS libraries we use at [MediaMonks](https://www.mediamonks.com/).)

## Example

See `./Example` on how to use `MMMArrayChanges` class to drive bulk animations of a `UITableView` properly.

### diffMap()

(See `./Tests/MMMArrayChangesTestCase.swift` for a more complete one.)

Imagine we are somewhere in a model representing a list of cookies updatable from a backend:

    var items: [CookieModel] = []
    // ...

And we've got our first ever update:

    let apiResponse: [CookieFromAPI] = [
    	CookieFromAPI(id: 1, name: "Almond biscuit"),
    	CookieFromAPI(id: 2, name: "Animal cracker"),
        // ...
    ]

Note that `CookieModel` objects in our list model are rich (["thick"](https://martinfowler.com/bliki/AnemicDomainModel.html)) and provide lots of extra functionality, while our `CookieFromAPI` are plain and simple structures coming directly from the API layer.

We could recreate all our models and notify the observers of the whole list every time we get a new list from the API:

    items = apiResponse.map { (plainCookie) -> CookieModel in
    	return CookieModel(apiModel: plainCookie)
    }

However if almost nothing has changed in the list, then it would be nicer (performance-wise and very often
visually), to nofity only the observers of updated cookies, like "Almond biscuit"'s in this case:

    let apiResponse2: [CookieFromAPI] = [
    	CookieFromAPI(id: 1, name: "Almond cookie"), // <-- changed name
    	CookieFromAPI(id: 2, name: "Animal cracker")
    ]

Simple `map()` would not be enough and we would need to figure our which cookies in our API response correspond to which cookies in our current list. We would also need to handle new cookies and the ones that are not in the list anymore. Also, in case such a list is also linked to a `UITableView`, then we would need to generate updates/animations without breaking it (something that's quite hard to do in case of multi-item updates).

Enter `MMMArrayChanges` (ObjC-friendly and `UITableView`-compatible) or, for a simple Swift cases, a `diffMap()` extension:

    items = items.diffMap(
    	// We need to tell it how to match elements in the current and source arrays by providing IDs that can be compared.
    	elementId: { cookie -> String in cookie.id },
    	sourceArray: apiResponse2,
    	// We decided to use the same IDs that are used by the models, i.e. string ones.
    	sourceElementId: { plainCookie -> String in "\(plainCookie.id)" },
    	added: { (apiModel) -> CookieModel in
    		// This is called for every plain API object that has no corresponding "thick" cookie model yet,
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

## TODO

- `MMMArrayChanges`: rename methods for Swift.
- `MMMArrayChanges`: get rid of a mutable array requirement in the Swift version of `apply(to:...)`.
- Add a version of `diffMap()` that's not applying changes right away but ony reports them?

---
