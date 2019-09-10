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

	private var newCookieListChanges: MMMArrayChanges?
	private var newCookieList: [CookieViewModel] = []
	private var lastReloaded: Date?
	private var deferredUpdateTimer: Timer?

	// What kind of reload we were doing the last time updateViewModel() has been called.
	private var reloadStage: ReloadStage = .none

	private enum ReloadStage {
		case none
		case rowReloadsOnly
		case otherUpdates
	}

	// We don't want to update the table view while animations are in progress, however we don't know how much time
	// exactly the animations take, so this has to be something large enough, like 1s.
	// Put something like 4 or 5 in case you are using slow animations on the simulator to see how things work.
	private let tableViewAnimationDuration: TimeInterval = 1

	private func updateViewModel() {

		guard let view = _view else {
			// It's quite possible that our observer is triggered before the view is loaded, we are subscribing quite early.
			return
		}

		// Check if we're still waiting for the animations related to the previous update to complete.
		if let lastReloaded = lastReloaded, -lastReloaded.timeIntervalSinceNow < tableViewAnimationDuration {

			// Looks like so, let's reschedule, if needed, and get back to updates later.
			if deferredUpdateTimer == nil {
				deferredUpdateTimer = Timer.scheduledTimer(
					withTimeInterval: max(0, tableViewAnimationDuration - (-lastReloaded.timeIntervalSinceNow)),
					repeats: false,
					block: { [weak self] _ in self?.updateViewModel() }
				)
			}
			return

		}

		deferredUpdateTimer?.invalidate()
		deferredUpdateTimer = nil

		// Toggle this condition to compare basic and animated versions of updates.
		if false {

			// Very basic version where view models are recreated every time something about the list changes.
			// (Sometimes that's enough though.)
			cookieList = model.items.map { CookieViewModel(model: $0) }
			view.tableView.reloadData()

		} else {

			// A version using MMMArrayChanges that:
			// 1) keeps instances of view model objects for the same model items;
			// 2) supports animated updates properly including mixed reloads and moves
			//    (the latter requires a two stage process).

			switch reloadStage {
			case .none, .otherUpdates:

				print("---")
				print("cookieList: \(cookieList)")
				print("model.items: \(model.items)")

				// Cannot modifie `cookieList` directly because of the two stage reload process.
				newCookieList = cookieList
				let changes = MMMArrayChanges.byUpdatingArray(
					&newCookieList, elementId: { $0.id },
					sourceArray: model.items, sourceElementId: { "\($0.id)" },
					update: { (cookieViewModel, cookieViewModelIndex, cookie, cookieIndex) -> Bool in
						// This is called for view models that were not added or removed so we can update their contents.
						let usedLargeCellBefore = cookieViewModel.useLargeCell
						// Trying to update every elements that's not new...
						cookieViewModel.update(model: cookie)
						// ...but recording updates only for the ones where a cell reload is needed.
						return usedLargeCellBefore != cookieViewModel.useLargeCell
					},
					remove: { (cookieViewModel, index) in
						// Nothing to do for removed cookies here, but we could mark them as such, for example,
						// so somebody still holding a reference to them knows they are old.
					},
					transform: { (cookie, cookieIndex) -> CookieViewModel in
						// And this is called for every new cookie found to make a new view model out of it.
						return CookieViewModel(model: cookie)
					}
				)

				// Need to remember changes for the next of our 2 stage reload process.
				newCookieListChanges = changes

				print("Changes: \(changes)")
				assert(
					newCookieList.map { $0.id } == model.items.map { "\($0.id)" },
					"The view model array with changes replayed should have the same elements as the source array"
				)

				// Performing row reloads first as in general they cannot be played together with moves within the same
				// beginUpdates()/endUpdates() block.
				let reloaded = changes.applyReloadsBefore(
					tableView: view.tableView,
					indexPathForItemIndex: { IndexPath(row: $0, section: 0) },
					reloadAnimation: .automatic
				)
				if reloaded {
					lastReloaded = Date()
				}
				reloadStage = .rowReloadsOnly
				// Need to handle normal updates afterwards. Calling ourselves to either reschedule or perform them asap.
				self.updateViewModel()

			case .rowReloadsOnly:

				guard let changes = newCookieListChanges else {
					preconditionFailure()
				}

				cookieList = newCookieList
				let reloaded = changes.applySkippingReloads(
					tableView: view.tableView,
					indexPathForItemIndex: { IndexPath(row: $0, section: 0) },
					deletionAnimation: .right,
					insertionAnimation: .left
				)
				if reloaded {
					lastReloaded = Date()
				}
				reloadStage = .otherUpdates
			}
		}
	}

	// MARK: - UITableViewDataSource

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return cookieList.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		let viewModel = cookieList[indexPath.row]

		let useLargeCell = viewModel.useLargeCell

		let identifier = useLargeCell ? "largeCell" : "smallCell"
		let cell: CookieCell = {
			if let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? CookieCell {
				return cell
			} else {
				return CookieCell(reuseIdentifier: identifier, largeStyle: useLargeCell)
			}
		}()

		cell.viewModel = viewModel

		return cell
	}
}

extension CookieListViewController {

	internal class CookieCell: UITableViewCell, CookieViewModelDelegate {

		public init(reuseIdentifier: String?, largeStyle: Bool) {

			super.init(style: .default, reuseIdentifier: reuseIdentifier)

			guard let textLabel = textLabel else {
				preconditionFailure()
			}

			textLabel.numberOfLines = 0
			if largeStyle {
				textLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
			} else {
				textLabel.font = UIFont.preferredFont(forTextStyle: .body)
			}
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

			guard let textLabel = self.textLabel else {
				preconditionFailure()
			}

			if let viewModel = viewModel {
				textLabel.text = viewModel.name
			} else {
				textLabel.text = nil
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
