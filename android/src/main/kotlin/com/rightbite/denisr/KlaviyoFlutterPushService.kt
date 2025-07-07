package com.rightbite.denisr

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.annotation.RequiresPermission
import androidx.annotation.WorkerThread
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.klaviyo.analytics.Klaviyo
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.appendKlaviyoExtras
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.body
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.channel_description
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.channel_id
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.channel_importance
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.channel_name
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.clickAction
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.deepLink
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.getColor
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.getSmallIcon
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.imageUrl
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.isKlaviyoNotification
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.notificationCount
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.notificationPriority
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.notificationTag
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.sound
import com.klaviyo.pushFcm.KlaviyoRemoteMessage.title
import io.flutter.Log
import java.net.URL
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

class KlaviyoFlutterPushService: FirebaseMessagingService() {
    companion object {
        private const val DOWNLOAD_TIMEOUT_MS = 5_000
        const val MESSAGE_MESSAGE_ID_KEY = "klaviyo_message_id_key"
        const val ACTION_NAME = "com.rightbite.denisr.OPEN"

        private fun generateId() = System.currentTimeMillis().toInt()
    }

    override fun onNewToken(newToken: String) {
        super.onNewToken(newToken)
        Klaviyo.setPushToken(newToken)
        KlaviyoEventChannelHandler.getInstance().onTokenChanged(newToken)
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS)
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        Log.i("KLAVIYO", "onMessageReceived $message")

        if (message.isKlaviyoNotification) {
            val hasPermissions = ActivityCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED

            if (!message.isKlaviyoNotification || !hasPermissions) {
                return
            }

            Log.i("KLAVIYO", "Displaying Klaviyo notification")

            createNotificationChannel(applicationContext, message)
            displayNotification(message)
        }
    }

    @RequiresPermission(Manifest.permission.POST_NOTIFICATIONS)
    @WorkerThread
    private fun displayNotification(message: RemoteMessage) {
        val notification = buildNotification(applicationContext, message)
        message.imageUrl?.applyToNotification(builder = notification)

        NotificationManagerCompat
            .from(applicationContext)
            .notify(
                message.notificationTag ?: generateId().toString(),
                0,
                notification.build()
            )
    }

    private fun createNotificationChannel(context: Context, message: RemoteMessage) {
        NotificationManagerCompat
            .from(context)
            .createNotificationChannel(
                NotificationChannelCompat.Builder(message.channel_id, message.channel_importance)
                    .setName(message.channel_name)
                    .setDescription(message.channel_description)
                    .build()
            )
    }

    private fun buildNotification(context: Context, message: RemoteMessage): NotificationCompat.Builder =
        NotificationCompat.Builder(context, message.channel_id)
            .setContentIntent(createIntent(context, message))
            .setSmallIcon(message.getSmallIcon(context))
            .also { message.getColor(context)?.let { color -> it.setColor(color) } }
            .setContentTitle(message.title)
            .setContentText(message.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message.body))
            .setSound(message.sound)
            .setNumber(message.notificationCount)
            .setPriority(message.notificationPriority)
            .setAutoCancel(true)

    private fun createIntent(context: Context, message: RemoteMessage): PendingIntent {
        val pkgName = context.packageName

        // Create intent to open the activity and/or deep link if specified
        // Else fall back on the default launcher intent for the package

        Log.i("KLAVIYO", "Message action: ${message.clickAction} - deeplink: ${message.deepLink}")

        val id = generateId()
        val klaviyoMessage = klaviyoRemoteMessageFromFirebaseRemoteMessage(message)

        KlaviyoEventChannelHandler.getInstance().receivedNotifications[id] = klaviyoMessage

        val intent = context.packageManager.getLaunchIntentForPackage(pkgName)
        val action =  intent
            ?.appendKlaviyoExtras(message)
            ?.apply {
            action = ACTION_NAME
            data = message.deepLink

            setPackage(pkgName)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MESSAGE_MESSAGE_ID_KEY, id)
        }

        return PendingIntent.getActivity(
            context,
            id,
            action,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT
        )
    }

    private fun URL.applyToNotification(builder: NotificationCompat.Builder) {
        val executor = Executors.newCachedThreadPool()
        var task: Future<Bitmap>? = null
        try {
            task = executor.submit<Bitmap> {
                // Start the download
                val bytes: ByteArray = openStream().use { connectionInputStream ->
                    connectionInputStream.readBytes()
                }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }
            // Await the image download with a timeout
            val bitmap = task.get(DOWNLOAD_TIMEOUT_MS.toLong(), TimeUnit.MILLISECONDS)

            // If completed, add the bitmap as the largeIcon (collapsed) and bigPicture (expanded)
            builder.setLargeIcon(bitmap)
            builder.setStyle(
                NotificationCompat.BigPictureStyle()
                    .bigPicture(bitmap)
                    .bigLargeIcon(null as Bitmap?)
            )
        } catch (e: ExecutionException) {
            Log.w("Klaviyo", "Image download failed: ${e.cause}", e)
        } catch (e: InterruptedException) {
           Log.w("Klaviyo", "Image download interrupted: ${e.cause}", e)
            Thread.currentThread().interrupt()
        } catch (e: TimeoutException) {
            // Note: we could continue the download but allow the notification to display
            // This would require also cancelling the download if the user taps on the notification
            // The behavior in this method is the same as FCM notification messages.
            Log.w("Klaviyo", "Image download timed out at ${DOWNLOAD_TIMEOUT_MS}ms", e)
        } finally {
            task?.cancel(true)
            executor.shutdown()
        }
    }
}
