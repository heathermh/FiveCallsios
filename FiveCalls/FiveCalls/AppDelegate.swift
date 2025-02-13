//
//  AppDelegate.swift
//  FiveCalls
//
//  Created by Ben Scheirman on 1/30/17.
//  Copyright © 2017 5calls. All rights reserved.
//

import UIKit
import SwiftUI
import OneSignal
import Firebase
import TipKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var navController: CustomNavigationController!
    
    let USE_NEW_SWIFTUI_INTERFACE = false
    var appState = AppState()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        if isUITesting() {
            resetData()
        }

        clearNotificationBadge()
        setAppearance()

        resetOrInitializeCountForRating()
        
        oneSignalStartup(launchOptions: launchOptions)
        OneSignal.setExternalUserId(AnalyticsManager.shared.callerID)

        FirebaseApp.configure()
        
        navController = R.storyboard.main.instantiateInitialViewController()
        window = UIWindow()
        if USE_NEW_SWIFTUI_INTERFACE {
            let store = Store(state: AppState(), middlewares: [appMiddleware()])
            window?.rootViewController = UIHostingController(rootView: IssueSplitView()
                .environmentObject(store))
            
            if #available(iOS 17.0, *) {
                try? Tips.configure()
            }
                
            if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasShownWelcomeScreen.rawValue) {
                showWelcome(store: store)
            }
        } else {
            window?.rootViewController = navController
            
            if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasShownWelcomeScreen.rawValue) {
                showWelcome()
            }
        }

        window?.makeKeyAndVisible()
        
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return false
        }
        // sets a string like 'usps-postal-service-covid-funding' that we can use when issues are loaded
        UserDefaults.standard.set(incomingURL.lastPathComponent, forKey: UserDefaultsKey.selectIssuePath.rawValue)
        AnalyticsManager.shared.trackEventOld(withName: "Info: Enter from Universal Link", andProperties: ["issue-slug": incomingURL.lastPathComponent])

        return true
    }
    
    func oneSignalStartup(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        if let infoPlist = Bundle.main.infoDictionary, let oneSignalAppID = infoPlist["OneSignalAppID"] as? String {
            OneSignal.initWithLaunchOptions(launchOptions)
            OneSignal.setAppId(oneSignalAppID)
        }
    }
    
    func transitionTo(rootViewController viewController: UIViewController) {
        guard let window = self.window else { return }
        guard window.rootViewController != viewController else { return }
        
        let snapshot = window.snapshotView(afterScreenUpdates: false)!
        viewController.view.addSubview(snapshot)
        window.rootViewController = viewController
        
        UIView.animate(withDuration: 0.5, animations: {
            snapshot.alpha = 0
            snapshot.frame.origin.y += window.frame.size.height
            snapshot.transform = snapshot.transform.scaledBy(x: 0.8, y: 0.8)
        }) { completed in
            snapshot.removeFromSuperview()
        }
    }
    
    func showWelcome() {
        guard let window = self.window else { return }
        let welcomeVC = R.storyboard.welcome.welcomeViewController()!
        let mainVC = window.rootViewController!
        welcomeVC.completionBlock = {
            UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasShownWelcomeScreen.rawValue)
            self.transitionTo(rootViewController: mainVC)
        }
        window.rootViewController = welcomeVC
    }
    
    func showWelcome(store: Store) {
        guard let window = self.window else { return }
        let mainVC = window.rootViewController!
        let welcomeVC = UIHostingController(rootView: Welcome(onContinue: {
            UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasShownWelcomeScreen.rawValue)
            self.transitionTo(rootViewController: mainVC)
        }).environmentObject(store))
        window.rootViewController = welcomeVC
    }
    
    func setAppearance() {
        if USE_NEW_SWIFTUI_INTERFACE {
            Appearance.swiftUISetup()
        } else {
            Appearance.setup()
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        // log in if not already logged in, and save the auth token for later reuse
        SessionManager.shared.startSession()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


    private func resetData() {
        // clear user defaults
        let appDomain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: appDomain)

        // clear any saved location data
        ContactLogs.removeData()
    }
    
    private func clearNotificationBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }


    private func resetOrInitializeCountForRating() {
        let defaults = UserDefaults.standard

        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

        if let storedVersion = defaults.string(forKey: UserDefaultsKey.appVersion.rawValue),
            currentVersion == storedVersion {
            return
        }

        defaults.setValue(currentVersion, forKey: UserDefaultsKey.appVersion.rawValue)
        defaults.set(Int(0), forKey: UserDefaultsKey.countOfCallsForRatingPrompt.rawValue)
    }

    static var isRunningUnitTests: Bool {
        return ProcessInfo.processInfo.environment.keys.contains("XCInjectBundleInto")
    }
}
