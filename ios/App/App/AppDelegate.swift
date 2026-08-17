import UIKit
import Capacitor
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?
    private var isFirebaseAllowed = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. Gán delegate sơ bộ cho NotificationCenter để không bỏ lỡ push khi app bật
        UNUserNotificationCenter.current().delegate = self

        // 2. Kiểm tra môi trường & Khởi tạo Firebase bất đồng bộ trên Background Thread
        // Giúp Main Thread giải phóng ngay lập tức -> Hết đơ/đen màn hình
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let allowed = self.checkIfFirebaseAllowed()
            
            DispatchQueue.main.async {
                self.isFirebaseAllowed = allowed
                if allowed {
                    FirebaseApp.configure()
                    Messaging.messaging().delegate = self
                    UIApplication.shared.registerForRemoteNotifications()
                    print("✅ [AppDelegate] Khởi tạo Firebase & Push Notifications thành công.")
                } else {
                    print("⚠️ [AppDelegate] Vô hiệu hóa Firebase & Push do môi trường không phù hợp.")
                }
            }
        }

        return true
    }

    // MARK: - Safe Environment Checkers (Chạy trên Background Thread)

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
            print("❌ [AppDelegate] Không tìm thấy hoặc lỗi đọc file GoogleService-Info.plist.")
            return false
        }

        if actualBundleID != plistBundleID {
            print("⚠️ [AppDelegate] Sai lệch Bundle ID (Thực tế: '\(actualBundleID)' vs Plist: '\(plistBundleID)').")
            return false
        }

        // 2. Kiểm tra embedded.mobileprovision bằng I/O an toàn
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let profileData = try? Data(contentsOf: URL(fileURLWithPath: profilePath)),
              let profileString = String(data: profileData, encoding: .ascii) else {
            // App đã được build Release/TestFlight (App Store bỏ file embedded.mobileprovision) -> Cho phép chạy
            return true
        }

        let hasAPNsCapability = profileString.contains("aps-environment")
        if !hasAPNsCapability {
            print("⚠️ [AppDelegate] Bỏ qua APNs: Provisioning Profile không chứa quyền 'aps-environment'.")
        }
        
        return hasAPNsCapability
        #endif
    }

    // MARK: - Push Notifications & Messaging Delegates

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard isFirebaseAllowed else { return }
        Messaging.messaging().apnsToken = deviceToken
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        if isFirebaseAllowed {
            print("⚠️ [AppDelegate] Lỗi đăng ký APNs: \(error.localizedDescription)")
            NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
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

    // MARK: - Universal Links & Deep Links (Capacitor Routing)

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
