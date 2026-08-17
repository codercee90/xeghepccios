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
        
        // 1. Kiểm tra môi trường an toàn trước khi kích hoạt Push/Firebase
        isFirebaseAllowed = shouldEnableFirebase()

        // 2. Chỉ khởi tạo Firebase, APNs và Notification Center khi môi trường hợp lệ
        if isFirebaseAllowed {
            UNUserNotificationCenter.current().delegate = self
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
            print("✅ [AppDelegate] Khởi tạo Firebase & Push Notifications thành công.")
        } else {
            print("⚠️ [AppDelegate] Phát hiện môi trường Ký cá nhân / 3uTools / Mất đồng bộ Bundle ID. Đã vô hiệu hóa Firebase & Push Notifications để bảo vệ App.")
        }

        return true
    }

    // MARK: - Safe Environment Checkers

    /// Kiểm tra điều kiện an toàn để bật Firebase & APNs
    private func shouldEnableFirebase() -> Bool {
        #if TARGET_OS_SIMULATOR
        return false
        #else
        // Kiểm tra 1: Xác minh sự tồn tại của file GoogleService-Info.plist và so sánh Bundle ID
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistDict = NSDictionary(contentsOfFile: plistPath),
              let plistBundleID = plistDict["BUNDLE_ID"] as? String,
              let actualBundleID = Bundle.main.bundleIdentifier else {
            print("❌ [AppDelegate] Bỏ qua Firebase: Không tìm thấy hoặc lỗi đọc file GoogleService-Info.plist.")
            return false
        }

        // Bỏ qua nếu Bundle ID thực tế không khớp với cấu hình Firebase
        if actualBundleID != plistBundleID {
            print("⚠️ [AppDelegate] Bỏ qua Firebase: Sai lệch Bundle ID (Thực tế: '\(actualBundleID)' vs Plist: '\(plistBundleID)').")
            return false
        }

        // Kiểm tra 2: Quét Provisioning Profile tìm Entitlement "aps-environment"
        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let profileData = try? Data(contentsOf: URL(fileURLWithPath: profilePath)),
              let profileString = String(data: profileData, encoding: .ascii) else {
            // Trường hợp Build Production/TestFlight (không chứa file embedded.mobileprovision) -> Cho phép chạy
            return true
        }

        // Chỉ trả về true nếu Profile có chứa quyền aps-environment
        let hasAPNsCapability = profileString.contains("aps-environment")
        if !hasAPNsCapability {
            print("⚠️ [AppDelegate] Bỏ qua APNs: Provisioning Profile không chứa quyền 'aps-environment'.")
        }
        
        return hasAPNsCapability
        #endif
    }

    // MARK: - Push Notifications & Messaging Delegates (Protected)

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
            completionHandler([.badge, .sound, .alert])
        } else {
            completionHandler([])
        }
    }

    // MARK: - Universal Links & Deep Links

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}