import Flutter
import KlaviyoSwift
import UIKit

/// A class that receives and handles calls from Flutter to complete the payment.
public class KlaviyoFlutterPlugin: NSObject, FlutterPlugin {
    private static let methodChannelName = "com.rightbite.denisr/klaviyo"
    
    private let METHOD_UPDATE_PROFILE = "updateProfile"
    private let METHOD_INITIALIZE = "initialize"
    private let METHOD_SEND_TOKEN = "sendTokenToKlaviyo"
    private let METHOD_SET_BADGE_COUNT = "setBadgeCount"
    private let METHOD_LOG_EVENT = "logEvent"
    private let METHOD_HANDLE_PUSH = "handlePush"
    private let METHOD_SET_EXTERNAL_ID = "setExternalId"
    private let METHOD_GET_EXTERNAL_ID = "getExternalId"
    private let METHOD_RESET_PROFILE = "resetProfile"
    private let METHOD_SET_EMAIL = "setEmail"
    private let METHOD_GET_EMAIL = "getEmail"
    private let METHOD_SET_PHONE_NUMBER = "setPhoneNumber"
    private let METHOD_GET_PHONE_NUMBER = "getPhoneNumber"
    private let METHOD_SET_FIRST_NAME = "setFirstName"
    private let METHOD_SET_LAST_NAME = "setLastName"
    private let METHOD_SET_ORGANIZATION = "setOrganization"
    private let METHOD_SET_TITLE = "setTitle"
    private let METHOD_SET_IMAGE = "setImage"
    private let METHOD_SET_ADDRESS1 = "setAddress1"
    private let METHOD_SET_ADDRESS2 = "setAddress2"
    private let METHOD_SET_CITY = "setCity"
    private let METHOD_SET_COUNTRY = "setCountry"
    private let METHOD_SET_LATITUDE = "setLatitude"
    private let METHOD_SET_LONGITUDE = "setLongitude"
    private let METHOD_SET_REGION = "setRegion"
    private let METHOD_SET_ZIP = "setZip"
    private let METHOD_SET_TIMEZONE = "setTimezone"
    private let METHOD_SET_CUSTOM_ATTRIBUTE = "setCustomAttribute"
    
    private let klaviyo = KlaviyoSDK()
    private let onMessageHandler = KlaviyoOnMessageHandler()
    private let onMessageOpenedAppHandler = KlaviyoOnMessageOpenedAppHandler()
    
    private let onTokenChangedHandler = KlaviyoOnTokenChangedHandler()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let channel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: messenger
        )
        let instance = KlaviyoFlutterPlugin()
        
        if #available(OSX 10.14, *) {
            let center = UNUserNotificationCenter.current()
            center.delegate = instance
        }
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        
        OnMessageStreamHandler.register(with: messenger, streamHandler: instance.onMessageHandler)
        OnMessageOpenedAppStreamHandler.register(with: messenger, streamHandler: instance.onMessageOpenedAppHandler)
        OnTokenChangedStreamHandler.register(with: messenger, streamHandler: instance.onTokenChangedHandler)
    }
    
    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        func setProfileAttribute(
            key: Profile.ProfileKey,
            name: String,
            argumentKey: String
        ) {
            guard
                let arguments = call.arguments as? [String: Any],
                let stringValue = arguments[argumentKey] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "\(name) must be a non-null String",
                        details: nil
                    )
                )
            }
            klaviyo.set(profileAttribute: key, value: stringValue)
            result("\(name) updated")
        }
        
        switch call.method {
        case METHOD_INITIALIZE:
            guard
                let arguments = call.arguments as? [String: Any],
                let apiKey = arguments["apiKey"] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "API key must be provided",
                        details: nil
                    )
                )
            }
            klaviyo.initialize(with: apiKey)
            UIApplication.shared.registerForRemoteNotifications()
            result("Klaviyo initialized")
            
        case METHOD_SEND_TOKEN:
            guard
                let arguments = call.arguments as? [String: Any],
                let tokenData = arguments["token"] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "Token must be provided",
                        details: nil
                    )
                )
            }
            klaviyo.set(pushToken: Data(hexString: tokenData))
            result("Token sent to Klaviyo")
            
        case METHOD_SET_BADGE_COUNT:
            guard
                let arguments = call.arguments as? [String: Any],
                let count = arguments["count"] as? Int
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "count must be an Int",
                        details: nil
                    )
                )
            }
            DispatchQueue.main.async {
                self.klaviyo.setBadgeCount(count)
                result("Badge count set")
            }
            
        case METHOD_UPDATE_PROFILE:
            guard
                let arguments = call.arguments as? [String: Any]
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "Profile must be provided",
                        details: nil
                    )
                )
            }
            // parsing location
            let address1 = arguments["address1"] as? String
            let address2 = arguments["address2"] as? String
            let latitude = (arguments["latitude"] as? String)?.toDouble
            let longitude = (arguments["longitude"] as? String)?.toDouble
            let region = arguments["region"] as? String
            
            var location: Profile.Location?
            
            if address1 != nil && address2 != nil && latitude != nil
                && longitude != nil && region != nil
            {
                location = Profile.Location(
                    address1: address1,
                    address2: address2,
                    latitude: latitude,
                    longitude: longitude,
                    region: region
                )
            }
            
            let profile = Profile(
                email: arguments["email"] as? String,
                phoneNumber: arguments["phone_number"] as? String,
                externalId: arguments["external_id"] as? String,
                firstName: arguments["first_name"] as? String,
                lastName: arguments["last_name"] as? String,
                organization: arguments["organization"] as? String,
                title: arguments["title"] as? String,
                image: arguments["image"] as? String,
                location: location,
                properties: arguments["properties"] as? [String: Any]
            )
            klaviyo.set(profile: profile)
            result("Profile updated")
            
        case METHOD_LOG_EVENT:
            guard
                let arguments = call.arguments as? [String: Any],
                let eventName = arguments["name"] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "Event name must be provided",
                        details: nil
                    )
                )
            }
            let event = Event(
                name: .customEvent(eventName),
                properties: arguments["metaData"] as? [String: Any]
            )
            
            klaviyo.create(event: event)
            result("Event: [\(event)] created")
            
        case METHOD_HANDLE_PUSH:
            guard
                let arguments = call.arguments as? [String: Any]
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "Push message must be provided",
                        details: nil
                    )
                )
            }
            
            if let properties = arguments["message"] as? [String: Any],
               properties["_k"] != nil
            {
                klaviyo.create(
                    event: Event(
                        name: .customEvent("$opened_push"),
                        properties: properties
                    )
                )
                
                return result(true)
            }
            result(false)
            
        case METHOD_GET_EXTERNAL_ID:
            result(klaviyo.externalId)
            
        case METHOD_RESET_PROFILE:
            klaviyo.resetProfile()
            result(true)
            
        case METHOD_GET_EMAIL:
            result(klaviyo.email)
            
        case METHOD_GET_PHONE_NUMBER:
            result(klaviyo.phoneNumber)
            
        case METHOD_SET_EXTERNAL_ID:
            guard
                let arguments = call.arguments as? [String: Any],
                let externalId = arguments["id"] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "External ID must be provided",
                        details: nil
                    )
                )
            }
            klaviyo.set(externalId: externalId)
            result("ID updated")
            
        case METHOD_SET_EMAIL:
            guard
                let arguments = call.arguments as? [String: Any],
                let email = arguments["email"] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "Email must be provided",
                        details: nil
                    )
                )
            }
            
            klaviyo.set(email: email)
            result("Email updated")
            
        case METHOD_SET_PHONE_NUMBER:
            guard
                let arguments = call.arguments as? [String: Any],
                let phoneNumber = arguments["phoneNumber"] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "Phone number must be provided",
                        details: nil
                    )
                )
            }
            
            klaviyo.set(phoneNumber: phoneNumber)
            result("Phone updated")
            
        case METHOD_SET_FIRST_NAME:
            setProfileAttribute(
                key: .firstName,
                name: "First name",
                argumentKey: "firstName"
            )
            
        case METHOD_SET_LAST_NAME:
            setProfileAttribute(
                key: .lastName,
                name: "Last name",
                argumentKey: "lastName"
            )
            
        case METHOD_SET_TITLE:
            setProfileAttribute(
                key: .title,
                name: "Title",
                argumentKey: "title"
            )
            
        case METHOD_SET_ORGANIZATION:
            setProfileAttribute(
                key: .organization,
                name: "Organization",
                argumentKey: "organization"
            )
            
        case METHOD_SET_IMAGE:
            setProfileAttribute(
                key: .image,
                name: "Image",
                argumentKey: "image"
            )
            
        case METHOD_SET_ADDRESS1:
            setProfileAttribute(
                key: .address1,
                name: "Address 1",
                argumentKey: "address"
            )
            
        case METHOD_SET_ADDRESS2:
            setProfileAttribute(
                key: .address2,
                name: "Address 2",
                argumentKey: "address"
            )
            
        case METHOD_SET_CITY:
            setProfileAttribute(key: .city, name: "City", argumentKey: "city")
            
        case METHOD_SET_COUNTRY:
            setProfileAttribute(
                key: .country,
                name: "Country",
                argumentKey: "country"
            )
            
        case METHOD_SET_LATITUDE:
            setProfileAttribute(
                key: .latitude,
                name: "Latitude",
                argumentKey: "latitude"
            )
            
        case METHOD_SET_LONGITUDE:
            setProfileAttribute(
                key: .longitude,
                name: "Longitude",
                argumentKey: "longitude"
            )
            
        case METHOD_SET_REGION:
            setProfileAttribute(
                key: .region,
                name: "Region",
                argumentKey: "region"
            )
            
        case METHOD_SET_ZIP:
            setProfileAttribute(key: .zip, name: "Zip", argumentKey: "zip")
            
        case METHOD_SET_TIMEZONE:
            // Klaviyo takes timezone from environment on iOS
            result("Success")
            
        case METHOD_SET_CUSTOM_ATTRIBUTE:
            guard
                let arguments = call.arguments as? [String: Any],
                let key = arguments["key"] as? String,
                let value = arguments["value"] as? String
            else {
                return result(
                    FlutterError(
                        code: "invalid_args",
                        message: "Method setCustomAttribute requires arguments {key: String, value: String}",
                        details: nil
                    )
                )
            }
            klaviyo.set(profileAttribute: .custom(customKey: key), value: value)
            result("Attribute \(key) updated")
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension String {
    var toDouble: Double {
        return Double(self) ?? 0.0
    }
}

extension Data {
    init(hexString: String) {
        self =
        hexString
            .dropFirst(hexString.hasPrefix("0x") ? 2 : 0)
            .compactMap { $0.hexDigitValue.map { UInt8($0) } }
            .reduce(
                into: (
                    data: Data(capacity: hexString.count / 2),
                    byte: nil as UInt8?
                )
            ) { partialResult, nibble in
                if let p = partialResult.byte {
                    partialResult.data.append(p + nibble)
                    partialResult.byte = nil
                } else {
                    partialResult.byte = nibble << 4
                }
            }.data
    }
}

extension KlaviyoFlutterPlugin: UNUserNotificationCenterDelegate {
    // below method will be called when the user interacts with the push notification
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        
        // If this notification is Klaviyo's notification we'll handle it
        // else pass it on to the next push notification service to which it may belong
        let handled = klaviyo.handle(notificationResponse: response, withCompletionHandler: completionHandler)
        if (handled) {
            onMessageOpenedAppHandler.onNotificationResponse(response)
        } else {
            completionHandler()
        }
    }
    
    // below method is called when the app receives push notifications when the app is the foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        var options: UNNotificationPresentationOptions = [.alert]
        if #available(iOS 14.0, *) {
            options = [.list, .banner]
        }
        
        onMessageHandler.onNotification(notification)
        
        completionHandler(options)
        
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        klaviyo.set(pushToken: deviceToken)
        
        let apnDeviceToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        onTokenChangedHandler.onTokenChanged(apnDeviceToken)
    }
    
}

private class KlaviyoOnMessageHandler: OnMessageStreamHandler {
    private var eventSink: PigeonEventSink<KlaviyoRemoteMessage>?
    private var latestMessage: KlaviyoRemoteMessage?
    
    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<KlaviyoRemoteMessage>) {
        eventSink = sink
        if let message = latestMessage {
            eventSink?.success(message)
            latestMessage = nil
        }
    }
    
    func onNotification(_ notification: UNNotification) {
        let remoteMessage = KlaviyoRemoteMessage(notification: notification)
        if let sink = eventSink {
            sink.success(remoteMessage)
        } else {
            latestMessage = remoteMessage
        }
    }
}

private class KlaviyoOnMessageOpenedAppHandler: OnMessageOpenedAppStreamHandler {
    private var eventSink: PigeonEventSink<KlaviyoRemoteMessage>?
    private var latestMessage: KlaviyoRemoteMessage?
    
    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<KlaviyoRemoteMessage>) {
        eventSink = sink
        if let message = latestMessage {
            eventSink?.success(message)
            latestMessage = nil
        }
    }
    
    func onNotificationResponse(_ notificationResponse: UNNotificationResponse) {
        let remoteMessage = KlaviyoRemoteMessage(notification: notificationResponse.notification)
        if let sink = eventSink {
            eventSink?.success(remoteMessage)
        } else {
            latestMessage = remoteMessage
        }
    }
}

private class KlaviyoOnTokenChangedHandler: OnTokenChangedStreamHandler {
    private var eventSink: PigeonEventSink<String>?
    private var latestToken: String?
    
    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<String>) {
        eventSink = sink
        if let token = latestToken {
            eventSink?.success(token)
        }
    }
    
    func onTokenChanged(_ token: String) {
        latestToken = token
        eventSink?.success(token)
    }
}

private extension KlaviyoRemoteMessage {
    init(notification: UNNotification) {
        let request = notification.request
        let content = request.content
        let userInfo = content.userInfo
        
        self.contentAvailable = false
        self.mutableContent = false
        self.data = [:]
        self.notification = KlaviyoRemoteNotification(notification: notification)
        
        for (key, value) in userInfo {
            guard let key = key as? String else {
                continue
            }
            
            if key == "gcm.message_id" || key == "google.message_id" || key == "message_id",
               let messageId = value as? String {
                self.messageId = messageId
                continue
            }
            
            if key == "messageType", let messageType = value as? String {
                self.messageType = messageType
                continue
            }
            
            if key == "collapseKey", let collapseKey = value as? String {
                self.collapseKey = collapseKey
                continue
            }
            
            if key == "from", let from = value as? String {
                self.from = from
                continue
            }
            
            if key == "google.c.a.ts", let sentTime = value as? String {
                self.sentTime = sentTime
                continue
            }
            
            if key == "aps" || key == "gcm." || key.hasPrefix("google.") || key == "fcm_options" {
                continue
            }
            
            self.data[key] = value;
        }
        
        if let aps = userInfo["aps"] as? [String: Any] {
            if let category = aps["category"] as? String {
                self.category = category
            }
            
            if let threadId = aps["thread-id"] as? String {
                self.threadId = threadId
            }
            
            if let contentAvailable = aps["content-available"] as? Bool {
                self.contentAvailable = contentAvailable
            }
            
            if let mutableContent = aps["mutable-content"] as? Bool {
                self.mutableContent = mutableContent
            }
        }
    }
}

private extension KlaviyoRemoteNotification {
    init(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        self.titleLocArgs = []
        self.bodyLocArgs = []
        self.apple = KlaviyoAppleNotification(notification: notification)
        
        
        guard let aps = userInfo["aps"] as? [String: Any] else {
            return
        }
        
        if let alert = aps["alert"] as? String {
            self.title = alert
        } else if let alertDict = aps["alert"] as? [String: Any] {
            if let title = alertDict["title"] as? String {
                self.title = title
            }
            
            if let titleLocKey = alertDict["title-loc-key"] as? String {
                self.titleLocKey = titleLocKey
            }
            
            if let titleLocArgs = alertDict["title-loc-args"] as? [String] {
                self.titleLocArgs = titleLocArgs
            }
            
            if let body = alertDict["body"] as? String {
                self.body = body
            }
            
            if let bodyLocKey = alertDict["body-loc-key"] as? String {
                self.bodyLocKey = bodyLocKey
            }
            
            if let bodyLocArgs = alertDict["body-loc-args"] as? [String] {
                self.bodyLocArgs = bodyLocArgs
            }
        }
        
        
    }
}

private extension KlaviyoAppleNotification {
    init(notification: UNNotification) {
        self.subtitleLocArgs = []
        
        let userInfo = notification.request.content.userInfo
        
        if let options = userInfo["fcm_options"] as? NSDictionary,
           let imageUrl = options["image"] as? String {
            self.imageUrl = imageUrl
        }
        
        guard let aps = userInfo["aps"] as? [String: Any],
              let alertDict = aps["alert"] as? [String: Any] else {
            return
        }
        
        
        if let subtitle = alertDict["subtitle"] as? String {
            self.subtitle = subtitle
        }
        
        if let subtitleLocKey = alertDict["subtitleloc-key"] as? String {
            self.subtitleLocKey = subtitleLocKey
        }
        
        if let subtitleLocArgs = alertDict["subtitle-loc-args"] as? [String] {
            self.subtitleLocArgs = subtitleLocArgs
        }
        
        if let badge = alertDict["badge"] as? String {
            self.badge = badge
        }
        
        if let sound = aps["sound"] as? String {
            self.sound = KlaviyoAppleNotificationSound(
                critical: false,
                name: sound,
                volume: 1
            )
        } else if let soundDict = aps["sound"] as? [String: Any] {
            self.sound = KlaviyoAppleNotificationSound(
                critical: soundDict["critical"] as? Bool ?? false,
                name: soundDict["name"] as? String,
                volume: soundDict["volume"] as? Double ?? 1
            )
        }
        
    }
}


