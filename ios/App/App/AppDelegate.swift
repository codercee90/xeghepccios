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
        
        // 1. Kiểm tra môi trường an toàn trước khi đụng vào Firebase
        isFirebaseAllowed = shouldEnableFirebase()

        // 2. Cấu hình Notification Center
        UNUserNotificationCenter.current().delegate = self

        // 3. Chỉ khởi tạo Firebase & APNs nếu môi trường hợp lệ
        if isFirebaseAllowed {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
            print("✅ [AppDelegate] Khởi tạo Firebase & Push Notifications thành công.")
        } else {
            print("⚠️ [AppDelegate] Môi trường 3uTools/Ký cá nhân/Bất đồng bộ Bundle ID. Đã TẮT TỰ ĐỘNG Firebase & APNs để tránh treo app.")
        }

        return true
    }

    // MARK: - Safe Environment Checkers

    /// Kiểm tra điều kiện an toàn để bật Firebase
    private func shouldEnableFirebase() -> Bool {
        #if TARGET_OS_SIMULATOR
        return false
        #else
        // Check 1: Bundle ID trong App phải trùng khớp với Bundle ID khai báo trong GoogleService-Info.plist
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistDict = NSDictionary(contentsOfFile: plistPath),
              let plistBundleID = plistDict["BUNDLE_ID"] as? String,
              let actualBundleID = Bundle.main.bundleIdentifier else {
            print("❌ [AppDelegate] Không tìm thấy hoặc lỗi đọc file GoogleService-Info.plist")
            return false
        }

        if actualBundleID != plistBundleID {
            print("⚠️ [AppDelegate] Mismatch Bundle ID! Actual: '\(actualBundleID)' vs Plist: '\(plistBundleID)'")
            return false
        }

        // Check 2: Kiểm tra quyền Push Notification trong provisioning profile (chống crash APNs khi ký cá nhân)
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let profileData = try? Data(contentsOf: URL(fileURLWithPath: profilePath)),
              let profileString = String(data: profileData, encoding: .ascii) else {
            // Không có file provisioning (VD: Build App Store / TF) -> Cho phép
            return true
        }

        return profileString.contains("aps-environment")
        #endif
    }

    // MARK: - Push Notifications & Messaging Delegates (Protected)

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard isFirebaseAllowed else { return }
        Messaging.messaging().apnsToken = deviceToken
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ [AppDelegate] Lỗi đăng ký APNs: \(error.localizedDescription)")
        if isFirebaseAllowed {
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
        completionHandler([.badge, .sound, .alert])
    }

    // MARK: - Universal Links & Deep Links

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
