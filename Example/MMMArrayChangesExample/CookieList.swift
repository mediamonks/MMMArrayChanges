//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import Foundation

/// This is our "list of cookies" model: it maintains a list of cookies and modifies them periodically simulating
/// external changes on the model.
class CookieList {

	public class Cookie: NSObject {

		public let id: Int
		public internal(set) var name: String

		internal init(id: Int, name: String) {
			self.id = id
			self.name = name
		}
	}

	// Want to be able to reproduce the same sequence of additions/removals.
	private var random = PseudoRandomSequence(seed: 12345)

	private var timer: Timer?

	public init() {
		// The timeout is slightly less than the animation timeout of the UITableView, so we can demonstrate an important issue.
		let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
			self?.update()
		}
		RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
		self.timer = timer
	}

	public private(set) var items: [Cookie] = []

	private weak var observer: CookieListObserver?

	public func addObserver(_ observer: CookieListObserver) {
		assert(self.observer == nil, "We support only one observer in this example")
		self.observer = observer
	}

	public func removeObserver(_ observer: CookieListObserver) {
		assert(self.observer === observer)
		self.observer = nil
	}

	// Source: https://en.wikipedia.org/wiki/List_of_cookies
	private var names: [String] = [
		"Aachener Printen", "Abernethy", "Acıbadem kurabiyesi", "Afghan biscuits", "Alfajor", "Almond biscuit", "Almond cake",
		"Amaretti di Saronno", "Animal cracker", "ANZAC biscuit", "Aparon", "Apas", "Apple cider cookie",
		"Ballokume (from Turkish bal-lokum)", "Barquillo", "Barquiron", "Basler Läckerli", "Leckerli, Läggerli",
		"Berger Cookie", "Berner Haselnusslebkuchen", "Berner Honiglebkuchen", "Biscocho", "Biscotti", "Biscuit",
		"Biscuit roll", "Bizcochito", "biscochito", "Black and white cookie", "Half-Moon cookie", "Boortsog", "Bourbon biscuit",
		"Bredela", "Bredele, Bredle or Winachtsbredele", "Broas", "Butter cookie", "Butter pecan", "Camachile cookie",
		"Caramel shortbread", "Millionaire's Shortbread", "Carrot cake cookie", "Cat's tongue cookie", "(langues de chat)",
		"Cavallucci", "Caycay", "Charcoal biscuit", "Chocolate biscuit", "Chocolate chip cookie",
		"Chocolate-coated marshmallow treats", "Chocolate Teacake", "Christmas cookies", "Cuchuflís or Cubanitos",
		"Coconut macaroon", "Cornish fairings", "Coyotas", "Cream cracker", "Cuccidati", "Custard cream",
		"Digestive biscuit", "Dutch letter", "Empire biscuit", "Fig roll", "Florentine Biscuit", "Flour kurabiye",
		"Fortune cookie", "Fudge cookie", "Galletas de bato", "Galletas de patatas", "Galletas del Carmen",
		"Galletas pesquera", "Garibaldi biscuit", "Ghorabiye", "Ghoriba", "Gingerbread", "Gingerbread man", "Ginger snaps",
		"Half-moon cookie", "Hamantash", "Jacobina", "Jammie Dodgers", "Joe Frogger", "Jodenkoek", "Jumble", "Kaasstengels",
		"Kahk", "Egypt", "Khapse", "Kichel", "Kleicha", "Koulourakia", "Kourabiedes", "Krumiri", "Krumkake", "Kue gapit",
		"Lady Finger", "Lebkuchen", "Lengua de gato", "Lincoln biscuit", "Linga", "Linzer torte", "Ma'amoul",
		"Macaroon", "Macaron", "Malted milk (biscuit)", "Mamón tostado", "Maple leaf cream cookies", "Marie biscuit",
		"Moravian spice cookies", "Nice biscuit", "Nocciolini di Canzo", "Oat crisps", "Oatmeal raisin", "Oreo",
		"Otap", "Paciencia", "Paborita", "Panellets", "Paprenjak", "Party ring", "Peanut butter cookie", "Petit-Beurre",
		"Pfeffernüsse", "Piaya", "Pignolo", "Piñata cookie", "Pinwheel cookies", "Polvorón", "Pizzelle",
		"Puto seco", "Putri salju", "Rainbow cookie", "Reshteh Khoshkar", "Ricciarelli", "Rich tea",
		"Rosca or biscocho de rosca", "Rosette", "Rosquillo", "Rum ball", "Russian tea cake", "Sandwich cookie", "Semprong",
		"Shortbread", "Silvana", "Snickerdoodle", "Speculaas", "Belgium", "Germany", "Springerle", "Spritzgebäck",
		"Stroopwafel", "Sugar cookie", "Tahini cookie", "Tareco", "Teiglach", "Tirggel", "Toll House Cookie",
		"Toruń gingerbread", "Ube crinkles", "Ugoy-ugoy", "Uraró", "Vanillekipferl", "Wafer", "Wibele"
	];

	private var nextId: Int = 0

	private func randomItemPosition() -> Int {
		return (0..<items.count).randomElement(using: &random) ?? 0
	}

	private func update() {

		if (0...100).randomElement(using: &random)! < 20 {

			// Want to add/remove/move items less often than doing updates in their contents.

			let numberOfRemovals = (0...1).randomElement(using: &random)!
			for _ in 0...numberOfRemovals {
				if items.count > 0 {
					items.remove(at: randomItemPosition())
				}
			}

			let numberOfAdditions = (0...1).randomElement(using: &random)!
			for _ in 0...numberOfAdditions {
				nextId += 1
				items.insert(
					Cookie(id: nextId, name: names[nextId % names.count]),
					at: randomItemPosition()
				)
			}

			let numberOfMoves = (0...1).randomElement(using: &random)!
			for _ in 0...numberOfMoves {
				if items.count > 0 {
					items.swapAt(randomItemPosition(), randomItemPosition())
				}
			}
		}

		let numberOfUpdates = (0...10).randomElement(using: &random)!
		for _ in 0...numberOfUpdates {
			if items.count > 0 {
				let cookie = items[randomItemPosition()]
				if cookie.name.hasSuffix("!") {
					cookie.name.removeLast()
				} else {
					cookie.name.append("!")
				}
			}
		}

		observer?.cookieListDidChange(self)
	}
}

protocol CookieListObserver: AnyObject {
	func cookieListDidChange(_ cookieList: CookieList)
}
