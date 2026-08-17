import UIKit
import Capacitor
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: CAPBridgeAppDelegate {

    private var isFirebaseAllowed = false

    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. GỌI SUPER BẮT BUỘC: Giúp Capacitor khởi tạo Window và WebView (Sửa lỗi màn hình đen)
        super.application(application, didFinishLaunchingWithOptions: launchOptions)

        // 2. Gán Delegate cho Notification Center
        UNUserNotificationCenter.current().delegate = self

        // 3. Xử lý Firebase an toàn trên Background Thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let allowed = self.checkIfFirebaseAllowed()
            
            DispatchQueue.main.async {
                self.isFirebaseAllowed = allowed
                if allowed {
                    // Tránh crash nếu Firebase đã được init ở đâu đó trước
                    if FirebaseApp.app() == nil {
                        FirebaseApp.configure()
                    }
                    Messaging.messaging().delegate = self
                    UIApplication.shared.registerForRemoteNotifications()
                    print("✅ [AppDelegate] Khởi tạo Firebase thành công.")
                } else {
                    print("⚠️ [AppDelegate] Môi trường Ký cá nhân/3uTools: Đã tắt Firebase & Push Notifications.")
                }
            }
        }

        return true
    }

    // MARK: - Safe Environment Checkers

    private func checkIfFirebaseAllowed() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // 1. Kiểm tra GoogleService-Info.plist & Bundle ID
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistData = FileManager.default.contents(atPath: plistPath),
              let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let plistBundleID = plistDict["BUNDLE_ID"] as? String,
              let actualBundleID = Bundle.main.bundleIdentifier else {
            return false
        }

        if actualBundleID != plistBundleID {
            return false
        }

        // 2. Kiểm tra aps-environment từ mobileprovision
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let profileData = try? Data(contentsOf: URL(fileURLWithPath: profilePath)),
              let profileString = String(data: profileData, encoding: .ascii) else {
            return true
        }

        return profileString.contains("aps-environment")
        #endif
    }

    // MARK: - Push Notifications Delegates

    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard isFirebaseAllowed else { return }
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        if isFirebaseAllowed {
            super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
        }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard isFirebaseAllowed else { return }
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if isFirebaseAllowed {
            if #available(iOS 14.0, *) {
                completionHandler([.badge, .sound, .banner, .list])
            } else {
                completionHandler([.badge, .sound, .alert])
            }
        } else {
            completionHandler([])
        }
    }

    // MARK: - Universal Links & Deep Links

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return super.application(app, open: url, options: options)
    }

    override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
