//
//  TinyStepsApp.swift
//  TinySteps
//
//  Created by Alexander Danmayer on 20.04.26.
//

import SwiftUI

@main
struct TinyStepsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .onAppear {
                    AuthRedirectBridge.shared.handler = { url in
                        dependencies.authController.handleRedirectURL(url)
                    }
                }
                .onOpenURL { url in
                    _ = dependencies.authController.handleRedirectURL(url)
                }
        }
    }
}
