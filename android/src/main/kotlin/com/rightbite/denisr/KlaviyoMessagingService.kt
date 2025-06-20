package com.rightbite.denisr

import com.google.firebase.messaging.RemoteMessage
import com.klaviyo.pushFcm.KlaviyoPushService

class KlaviyoMessagingService(
    val onMessage: (message: RemoteMessage) -> Unit,
    val onToken: (token: String) -> Unit,
) : KlaviyoPushService() {


    override fun onNewToken(newToken: String) {
        onToken(newToken)
        super.onNewToken(newToken)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        onMessage(message)
        super.onMessageReceived(message)
    }
}