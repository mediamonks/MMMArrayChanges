//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import MMMArrayChanges
import UIKit

class CookieListViewController: UIViewController, CookieListObserver, UITableViewDataSource {

	// Our view model is updated from this list.
	private let model = CookieList()

	public init() {
    	super.init(nibName: nil, bundle: nil)
    	model.addObserver(self)
	}

	deinit {
    	model.removeObserver(self)
	}

	public required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private weak var _view: View?

	override func loadView() {
		let v = View()
		_view = v
		self.view = v
	}

	override func viewDidLoad() {

		super.viewDidLoad()

		updateViewModel()

		guard let view = _view else { preconditionFailure() }

		view.tableView.dataSource = self
	}

	// MARK: - CookieListObserver

	public func cookieListDidChange(_ cookieList: CookieList) {
		updateViewModel()
	}

	// This is our list view model for the sake of this example, just a list of items we deal with directly in here.
	private var cookieList: [CookieViewModel] = []

	private var lastUpdated: Date?

	private var updateTimer: Timer?

	private func updateViewModel() {

		guard let view = _view else {
			// It's quite possible that our observer is triggered before the view is loaded, we are subscribing quite early.
			return
		}

		// Toggle this condition to compare basic and animated versions of updates.
		if false {

			// Very basic version where view models are recreated every time something about the list changes.
			// (Sometimes that's enough though.)
			cookieList = model.items.map { CookieViewModel(model: $0) }
			view.tableView.reloadData()

		} else {

			// A version using MMMArrayChanges that:
			// 1) keeps instances of view model objects for the same model items;
			// 2) supports animated updates properly.

			do {
				// See if enough time has passed since the last update, as the animation can be still in progress
				// and we don't want to disturb it.
				// We don't know how much time it usually takes, thus 1 second here.
				if let lastUpdated = lastUpdated, -lastUpdated.timeIntervalSinceNow < 1 {
					// Let's reschedule the update for some time later to not interfere with the current one.
					updateTimer = Timer.scheduledTimer(
						withTimeInterval: 0.1, // Can calculate this more precisely of course.
						repeats: false,
						block: { [weak self] _ in
							self?.updateViewModel()
						}
					)
					return
				}

				updateTimer?.invalidate()
				updateTimer = nil
			}

			let changes = MMMArrayChanges(
				oldArray: cookieList, oldElementId: { $0.id },
				newArray: model.items, newElementId: { "\($0.id)" },
				hasUpdatedContents: { (cookieViewModel, cookie) -> Bool in
					// We can check what's new here or we can simply return `false` to let the `update`
					// block in the apply() call below called for every element that's till here
					// and let it decide on what's new and wheather or not observers should be called.
					return cookieViewModel.name != cookie.name
				}
			)

			changes.applyToArray(
				&cookieList,
				newArray: model.items,
				transform: { CookieViewModel(model: $0) },
				update: { (cookiewViewModel, cookie) in
					cookiewViewModel.update(model: cookie)
				}
			)

			assert(
				cookieList.map { $0.id } == model.items.map { "\($0.id)" },
				"The view model array with changes replayed should have the same elements as the source array"
			)

			changes.applyToTableView(
				view.tableView,
				indexPathForItemIndex: { IndexPath(row: $0, section: 0) },
				deletionAnimation: .right,
				insertionAnimation: .left
				// In our case we don't need to reload cells as they directly monitor the view models
				// and their side does not need to change.
				//~ reloadAnimation: .automatic
			)

			lastUpdated = Date()
		}
	}

	// MARK: - UITableViewDataSource

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return cookieList.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		let identifier = "cookieCell"
		let cell: CookieCell = {
			if let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? CookieCell {
				return cell
			} else {
				return CookieCell(reuseIdentifier: identifier)
			}
		}()

		cell.viewModel = cookieList[indexPath.row]

		return cell
	}
}

extension CookieListViewController {

	internal class CookieCell: UITableViewCell, CookieViewModelDelegate {

		public init(reuseIdentifier: String?) {
			super.init(style: .default, reuseIdentifier: reuseIdentifier)
		}

		required init?(coder aDecoder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		public var viewModel: CookieViewModel? {
			didSet {
				if viewModel !== oldValue {
					oldValue?.delegate = nil
					viewModel?.delegate = self
					update()
				}
			}
		}

		private func update() {
			if let viewModel = viewModel {
				self.textLabel?.text = viewModel.name
			} else {
				self.textLabel?.text = nil
			}
		}

		// MARK: - CookieViewModelDelegate

		func cookieViewModelDidChange(viewModel: CookieViewModel) {
			update()
		}
	}

	internal class View: UIView {

		public let tableView = UITableView()

		public required init?(coder aDecoder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		public init() {

			super.init(frame: .zero)

			do {
				self.backgroundColor = .white

				self.tableView.translatesAutoresizingMaskIntoConstraints = false
				self.addSubview(tableView)
			}

			do {
				let views = [ "tableView": tableView ]

				NSLayoutConstraint.activate(NSLayoutConstraint.constraints(
					withVisualFormat: "H:|[tableView]|",
					options: [], metrics: nil, views: views
				))
				NSLayoutConstraint.activate(NSLayoutConstraint.constraints(
					withVisualFormat: "V:|[tableView]|",
					options: [], metrics: nil, views: views
				))
			}
		}
	}
}
