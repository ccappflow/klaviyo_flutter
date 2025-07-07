package com.rightbite.denisr

import KlaviyoAndroidNotification
import KlaviyoAndroidNotificationPriority
import OnMessageOpenedAppStreamHandler
import OnMessageStreamHandler
import KlaviyoRemoteMessage
import KlaviyoRemoteNotification
import OnTokenChangedStreamHandler
import PigeonEventSink
import android.content.Intent
import com.google.firebase.messaging.RemoteMessage
import io.flutter.Log
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class KlaviyoEventChannelHandler {

    companion object {
        private var instance: KlaviyoEventChannelHandler? = null

        fun getInstance(): KlaviyoEventChannelHandler {
            if (instance == null) {
                instance = KlaviyoEventChannelHandler()
            }
            return instance!!
        }
    }

    private val onMessageHandler = KlaviyoOnMessageHandler()
    private val onMessageOpenedAppHandler = KlaviyoOnMessageOpenedAppHandler()
    private val onTokenChangedHandler = KlaviyoOnTokenChangedHandler()

    val messages = HashMap<Int, KlaviyoRemoteMessage>()

    fun onAttachedToEngine(messenger: BinaryMessenger) {
        OnMessageStreamHandler.register(
            messenger,
            streamHandler = onMessageHandler
        )
        OnMessageOpenedAppStreamHandler.register(
            messenger,
            streamHandler = onMessageOpenedAppHandler
        )
        OnTokenChangedStreamHandler.register(
            messenger,
            streamHandler = onTokenChangedHandler
        )
    }

    fun onTokenChanged(newToken: String) {
        onTokenChangedHandler.onTokenChanged(newToken);
    }

    fun onMessage(message: RemoteMessage) {
        onMessageHandler.onMessage(message);
    }

    fun onKlaviyoMessage(message: KlaviyoRemoteMessage) {
        onMessageHandler.onKlaviyoMessage(message)
    }

    fun maybeHandleIntent(intent: Intent) {
        val isKlaviyoAction = intent.action == KlaviyoFlutterPushService.ACTION_NAME
        if (!isKlaviyoAction) {
            return
        }
        val messageId = intent.getIntExtra(
            KlaviyoFlutterPushService.MESSAGE_MESSAGE_ID_KEY,
            -1
        )
        if (messageId == -1) {
            return
        }
        val message = messages[messageId]
        if (message != null) {
            onKlaviyoMessage(message)
        }
    }
}

private class KlaviyoOnMessageHandler : OnMessageStreamHandler() {
    private var eventSink: PigeonEventSink<KlaviyoRemoteMessage>? = null
    private var latestMessage: KlaviyoRemoteMessage? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<KlaviyoRemoteMessage>) {
        eventSink = sink
        Log.i("KLAVIYO", "onMessageHandler onListen, message: $latestMessage")
        latestMessage?.let { message ->
            CoroutineScope(Dispatchers.Main).launch {
                sink.success(message)
            }
            latestMessage = null
        }
    }

    fun onMessage(message: RemoteMessage) {
        val klaviyoMessage = klaviyoRemoteMessageFromFirebaseRemoteMessage(message)
       onKlaviyoMessage(klaviyoMessage)
    }

    fun onKlaviyoMessage(klaviyoMessage: KlaviyoRemoteMessage) {
        Log.i("KLAVIYO", "onNotification sink: $eventSink")
        eventSink?.also { sink ->
            Log.i("KLAVIYO", "onNotification send message to sink")
            CoroutineScope(Dispatchers.Main).launch {
                sink.success(klaviyoMessage)
            }
        } ?: run {
            Log.i("KLAVIYO", "onNotification set latestMessage")
            latestMessage = klaviyoMessage
        }
    }
}

private class KlaviyoOnMessageOpenedAppHandler: OnMessageOpenedAppStreamHandler() {
    private var eventSink: PigeonEventSink<KlaviyoRemoteMessage>? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<KlaviyoRemoteMessage>) {
        eventSink = sink
    }

    fun onNotification(message: RemoteMessage) {
        CoroutineScope(Dispatchers.Main).launch {
            eventSink?.success(
                klaviyoRemoteMessageFromFirebaseRemoteMessage(message)
            )
        }
    }
}

private class KlaviyoOnTokenChangedHandler: OnTokenChangedStreamHandler() {
    private var eventSink: PigeonEventSink<String>? = null
    private var latestToken: String? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<String>) {
        eventSink = sink
        latestToken?.let { token ->
            CoroutineScope(Dispatchers.Main).launch {
                eventSink?.success(token)
            }
        }
    }

    fun onTokenChanged(token: String) {
        latestToken = token
        CoroutineScope(Dispatchers.Main).launch {
            eventSink?.success(token)
        }
    }
}

fun klaviyoRemoteMessageFromFirebaseRemoteMessage(message: RemoteMessage): KlaviyoRemoteMessage =
    KlaviyoRemoteMessage(
        senderId = message.senderId,
        from = message.from,
        messageId = message.messageId,
        messageType = message.messageType,
        data = message.data,
        ttl = message.ttl.toLong(),
        collapseKey = message.collapseKey,
        notification = klaviyoRemoteNotificationFromFirebaseRemoteNotification(message.notification),
        mutableContent = false,
        contentAvailable = false,
        category = null,
        threadId = null,
        sentTime = null,

        )

private fun klaviyoRemoteNotificationFromFirebaseRemoteNotification(notification: RemoteMessage.Notification?): KlaviyoRemoteNotification? {
    if (notification == null) {
        return null;
    }

    return KlaviyoRemoteNotification(
        title = notification.title,
        titleLocArgs = notification.titleLocalizationArgs?.toList() ?: emptyList(),
        titleLocKey = notification.titleLocalizationKey,
        body = notification.body,
        bodyLocArgs = notification.bodyLocalizationArgs?.toList() ?: emptyList(),
        bodyLocKey = notification.bodyLocalizationKey,
        android = KlaviyoAndroidNotification(
            channelId = notification.channelId,
            clickAction = notification.clickAction,
            color = notification.color,
            count = notification.notificationCount?.toLong(),
            imageUrl = notification.imageUrl?.toString(),
            link = notification.link?.toString(),
            smallIcon = notification.icon,
            tag = notification.tag,
            sound = notification.sound,
            ticker = notification.ticker,
            priority = notification.notificationPriority?.let { priority ->
                KlaviyoAndroidNotificationPriority.ofRaw(priority)
            } ?: KlaviyoAndroidNotificationPriority.DEFAULT_PRIORITY,
        )
    );
}