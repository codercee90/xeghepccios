import UIKit
import Capacitor
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. Cấu hình Firebase SDK
        FirebaseApp.configure()

        // 2. Cấu hình Notification Center & Firebase Messaging
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // 3. Kiểm tra xem profile có hỗ trợ Push Notifications không trước khi đăng ký
        if isPushNotificationSupported() {
            application.registerForRemoteNotifications()
        } else {
            print("⚠️ [AppDelegate] Môi trường ký cá nhân/3uTools không hỗ trợ Push. Đã bỏ qua đăng ký APNs để tránh crash.")
        }

        return true
    }

    // Hàm kiểm tra môi trường ký (Chống crash khi ký cá nhân qua 3uTools)
    private func isPushNotificationSupported() -> Bool {
        #if TARGET_OS_SIMULATOR
        return false
        #else
        // Đọc nhị phân embedded.mobileprovision xem có quyền aps-environment không
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .ascii) else {
            // Nếu không tìm thấy profile (Build App Store chuẩn) -> Cho phép chạy bình thường
            return true
        }
        
        // Nếu dùng chứng chỉ cá nhân (Free Personal Team) hoặc thiếu quyền aps-environment -> Trả về false
        return content.contains("aps-environment")
        #endif
    }

    // Đăng ký APNs Token thành công
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: deviceToken)
    }

    // Lỗi khi đăng ký APNs (Bắt ngoại lệ an toàn, không throw crash)
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ [AppDelegate] Lỗi đăng ký APNs: \(error.localizedDescription)")
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }

    // Ủy quyền delegate FirebaseMessaging nhận Token thành công
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }

    // Xử lý thông báo khi ứng dụng đang chạy foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .alert])
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}