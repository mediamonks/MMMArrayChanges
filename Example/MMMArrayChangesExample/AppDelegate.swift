//
// MMMArrayChanges.
// Copyright (C) 2019 MediaMonks. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
	) -> Bool {

		let rootViewController = CookieListViewController()
		
		let window = UIWindow(frame: UIScreen.main.bounds)
		window.rootViewController = rootViewController
		window.makeKeyAndVisible()
		self.window = window

		return true
	}
}

