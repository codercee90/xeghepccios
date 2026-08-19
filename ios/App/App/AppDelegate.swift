import UIKit
import Capacitor
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    var window: UIWindow?

    // Biến flag kiểm tra môi trường sideload (Giữ nguyên)
    private var isFirebaseAllowed = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 1. Gán Delegate cho Notification Center NGAY ĐẦU HÀM
        UNUserNotificationCenter.current().delegate = self

        // 2. Tự khởi tạo CAPBridgeViewController để load Web App Capacitor
        let window = UIWindow(frame: UIScreen.main.bounds)
        let customBgColor = UIColor(red: 242/255.0, green: 242/255.0, blue: 247/255.0, alpha: 1.0)
        window.backgroundColor = customBgColor
        
        let bridgeVC = CAPBridgeViewController()
        bridgeVC.view.backgroundColor = customBgColor
        window.rootViewController = bridgeVC
        window.makeKeyAndVisible()
        self.window = window

        // 3. Kiểm tra môi trường ĐỒNG BỘ (SYNC) để tránh mất sự kiện Cold Start
        self.isFirebaseAllowed = self.checkIfFirebaseAllowed()
        
        if self.isFirebaseAllowed {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
            Messaging.messaging().delegate = self
            
            // Xin quyền thông báo & Đăng ký APNs
            self.requestNotificationPermission(application: application)
            
            print("✅ [AppDelegate] Firebase & Push Notification đã sẵn sàng.")
        } else {
            print("⚠️ [AppDelegate] Đã tắt Firebase (Môi trường không phù hợp hoặc ký cá nhân).")
        }

        return true
    }

    // MARK: - Xin quyền thông báo (Bắt buộc cho iOS)
    private func requestNotificationPermission(application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("❌ Lỗi xin quyền Push: \(error.localizedDescription)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ Người dùng từ chối cấp quyền thông báo.")
            }
        }
    }

    // MARK: - Safe Environment Checkers (Bypasser) - GIỮ NGUYÊN LOGIC CỦA BẠN
    private func checkIfFirebaseAllowed() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
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

        guard let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let profileData = try? Data(contentsOf: URL(fileURLWithPath: profilePath)),
              let profileString = String(data: profileData, encoding: .ascii) else {
            return true
        }

        return profileString.contains("aps-environment")
        #endif
    }

    // MARK: - Lifecycle & Badge Reset
    func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - Push Notifications Delegates

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        if isFirebaseAllowed {
            Messaging.messaging().apnsToken = deviceToken
            // Chuyển Token cho Capacitor Proxy phân phối
            ApplicationDelegateProxy.shared.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        if isFirebaseAllowed {
            ApplicationDelegateProxy.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
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

    // Hiển thị thông báo khi App đang mở trên màn hình (Foreground)
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

    // BẮT SỰ KIỆN CLICK VÀO THÔNG BÁO (Tất cả trạng thái: Killed, Background, Foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if isFirebaseAllowed {
            // Chuyển giao hoàn toàn cho Capacitor Proxy tự queue và bắn Event xuống JS
            ApplicationDelegateProxy.shared.userNotificationCenter(center, didReceive: response) {
                UIApplication.shared.applicationIconBadgeNumber = 0
                completionHandler()
            }
        } else {
            completionHandler()
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
