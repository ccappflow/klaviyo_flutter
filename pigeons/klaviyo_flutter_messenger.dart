import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/klaviyo_flutter_messenger.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/com/rightbite/denisr/src/KlaviyoFlutterMessenger.g.kt',
    kotlinOptions: KotlinOptions(),
    swiftOut: 'ios/Classes/KlaviyoFlutterMessenger.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'pigeon_example_package',
  ),
)
@EventChannelApi()
abstract class KlaviyoFlutterMessenger {
  KlaviyoRemoteMessage onMessage();
  KlaviyoRemoteMessage onMessageOpenedApp();
}

class KlaviyoRemoteMessage {
  KlaviyoRemoteMessage({
    this.senderId,
    this.category,
    this.collapseKey,
    required this.contentAvailable,
    required this.data,
    this.from,
    this.messageId,
    this.messageType,
    required this.mutableContent,
    this.notification,
    this.sentTime,
    this.threadId,
    this.ttl,
  });

  /// The ID of the upstream sender location.
  final String? senderId;

  /// The iOS category this notification is assigned to.
  final String? category;

  /// The collapse key a message was sent with. Used to override existing messages with the same key.
  final String? collapseKey;

  /// Whether the iOS APNs message was configured as a background update notification.
  final bool contentAvailable;

  /// Any additional data sent with the message.
  final Map<String?, Object?> data;

  /// The topic name or message identifier.
  final String? from;

  /// A unique ID assigned to every message.
  final String? messageId;

  /// The message type of the message.
  final String? messageType;

  /// Whether the iOS APNs `mutable-content` property on the message was set
  /// allowing the app to modify the notification via app extensions.
  final bool mutableContent;

  /// Additional Notification data sent with the message.
  final KlaviyoRemoteNotification? notification;

  /// The time the message was sent, represented as a [String].
  final String? sentTime;

  /// An iOS app specific identifier used for notification grouping.
  final String? threadId;

  /// The time to live for the message in seconds.
  final int? ttl;
}

class KlaviyoRemoteNotification {
  KlaviyoRemoteNotification(
    this.android,
    this.apple,
    this.web,
    this.title,
    this.titleLocArgs,
    this.titleLocKey,
    this.body,
    this.bodyLocArgs,
    this.bodyLocKey,
  );

  /// Android specific notification properties.
  final KlaviyoAndroidNotification? android;

  /// Apple specific notification properties.
  final KlaviyoAppleNotification? apple;

  /// Web specific notification properties.
  final KlaviyoWebNotification? web;

  /// The notification title.
  final String? title;

  /// Any arguments that should be formatted into the resource specified by titleLocKey.
  final List<String> titleLocArgs;

  /// The native localization key for the notification title.
  final String? titleLocKey;

  /// The notification body content.
  final String? body;

  /// Any arguments that should be formatted into the resource specified by bodyLocKey.
  final List<String> bodyLocArgs;

  /// The native localization key for the notification body content.
  final String? bodyLocKey;
}

/// Android specific properties of a [KlaviyoRemoteNotification].
///
/// This will only be populated if the current device is Android.
class KlaviyoAndroidNotification {
  KlaviyoAndroidNotification({
    this.channelId,
    this.clickAction,
    this.color,
    this.count,
    this.imageUrl,
    this.link,
    required this.priority,
    this.smallIcon,
    this.sound,
    this.ticker,
    this.tag,
  });

  /// The channel the notification is delivered on.
  final String? channelId;

  /// A spcific click action was defined for the notification.
  ///
  /// This property is not required to handle user interaction.
  final String? clickAction;

  /// The color of the notification.
  final String? color;

  /// The current notification count for the application.
  final int? count;

  /// The image URL for the notification.
  ///
  /// Will be `null` if the notification did not include an image.
  final String? imageUrl;

  // ignore: public_member_api_docs
  final String? link;

  /// The priority for the notifcation.
  ///
  /// This property only has impact on devices running Android 8.0 (API level 26) +.
  /// Later than this, they use the channel importance instead.
  final KlaviyoAndroidNotificationPriority priority;

  /// The resource file name of the small icon shown in the notification.
  final String? smallIcon;

  /// The resource file name of the sound used to alert users to the incoming notification.
  final String? sound;

  /// Ticker text for the notification, used for accessibility purposes.
  final String? ticker;

  /// The tag of the notification.
  final String? tag;
}

/// Apple specific properties of a [KlaviyoRemoteNotification].
///
/// This will only be populated if the current device is Apple based (iOS/MacOS).
class KlaviyoAppleNotification {
  KlaviyoAppleNotification({
    this.badge,
    this.sound,
    this.imageUrl,
    this.subtitle,
    required this.subtitleLocArgs,
    this.subtitleLocKey,
  });

  /// The value which sets the application badge.
  final String? badge;

  /// Sound values for the incoming notification.
  final KlaviyoAppleNotificationSound? sound;

  /// The image URL for the notification.
  ///
  /// Will be `null` if the notification did not include an image.
  final String? imageUrl;

  /// Any subtile text on the notification.
  final String? subtitle;

  /// Any arguments that should be formatted into the resource specified by subtitleLocKey.
  final List<String> subtitleLocArgs;

  /// The native localization key for the notification subtitle.
  final String? subtitleLocKey;
}

/// Represents the sound property for [KlaviyoAppleNotification]
class KlaviyoAppleNotificationSound {
  KlaviyoAppleNotificationSound({
    required this.critical,
    this.name,
    required this.volume,
  });

  /// Whether or not the notification sound was critical.
  final bool critical;

  /// The resource name of the sound played.
  final String? name;

  /// The volume of the sound.
  ///
  /// This value is a number between 0.0 & 1.0.
  final double volume;
}

/// Web specific properties of a [KlaviyoRemoteNotification].
class KlaviyoWebNotification {
  KlaviyoWebNotification({
    this.analyticsLabel,
    this.image,
    this.link,
  });

  /// Optional message label for custom analytics.
  final String? analyticsLabel;

  /// The image URL for the notification.
  ///
  /// Will be `null` if the notification did not include an image.
  final String? image;

  /// The url which is typically being navigated to when the notification is clicked.
  final String? link;
}

/// An enum representing a notification setting for this app on the device.
enum KlaviyoAppleNotificationSetting {
  /// This setting is currently disabled by the user.
  disabled,

  /// This setting is currently enabled.
  enabled,

  /// This setting is not supported on this device.
  ///
  /// Usually this means that the iOS version required for this setting has not been met,
  /// or the platform is not Apple.
  notSupported,
}

/// An enum representing the show previews notification setting for this app on the device.
enum KlaviyoAppleShowPreviewSetting {
  /// Always show previews even if the device is currently locked.
  always,

  /// Never show previews.
  never,

  /// This setting is not supported on this device.
  ///
  /// Usually this means that the iOS version required for this setting (iOS 11+) has not been met,
  /// or the platform is not Apple.
  notSupported,

  /// Only show previews when the device is unlocked.
  whenAuthenticated,
}

/// Represents the current status of the platforms notification permissions.
enum KlaviyoAuthorizationStatus {
  /// The app is authorized to create notifications.
  authorized,

  /// The app is not authorized to create notifications.
  denied,

  /// The app user has not yet chosen whether to allow the application to create
  /// notifications. Usually this status is returned prior to the first call
  /// of [requestPermission].
  notDetermined,

  /// The app is currently authorized to post non-interrupting user notifications.
  provisional,
}

/// An enum representing a notification priority on Android.
///
/// Note; on devices which have channel support (Android 8.0 (API level 26) +),
/// this value will be ignored. Instead, the channel "importance" level is used.
enum KlaviyoAndroidNotificationPriority {
  /// The application small icon will not show up in the status bar, or alert the user. The notification
  /// will be in a collapsed state in the notification shade and placed at the bottom of the list.
  minimumPriority,

  /// The application small icon will show in the device status bar, however the notification will
  /// not alert the user (no sound or vibration). The notification will show in it's expanded state
  /// when the notification shade is pulled down.
  lowPriority,

  /// When a notification is received, the device smallIcon will appear in the notification shade.
  /// When the user pulls down the notification shade, the content of the notification will be shown
  /// in it's expanded state.
  defaultPriority,

  /// Notifications will appear on-top of applications, allowing direct interaction without pulling
  /// own the notification shade. This level is used for urgent notifications, such as
  /// incoming phone calls, messages etc, which require immediate attention.
  highPriority,

  /// The highest priority level a notification can be set to.
  maximumPriority,
}
