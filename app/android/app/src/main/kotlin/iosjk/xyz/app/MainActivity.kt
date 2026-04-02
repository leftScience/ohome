package iosjk.xyz.app

import android.app.PictureInPictureParams
import android.content.Context
import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

class MainActivity : AudioServiceActivity() {
    private val networkChannelName = "ohome/network_info"
    private val pictureInPictureChannelName = "ohome/picture_in_picture"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var pictureInPictureEnabled: Boolean = false
    private var pictureInPictureAutoEnter: Boolean = true
    private var pictureInPictureAspectRatio: Rational = Rational(16, 9)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, networkChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getActiveIpv4Cidr" -> result.success(getActiveIpv4Cidr())
                    "acquireMulticastLock" -> {
                        acquireMulticastLock()
                        result.success(null)
                    }
                    "releaseMulticastLock" -> {
                        releaseMulticastLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pictureInPictureChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPictureInPictureSupported" ->
                    result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(
                                "android.software.picture_in_picture",
                            ),
                    )
                "setPictureInPictureEnabled" -> {
                    pictureInPictureEnabled = call.argument<Boolean>("enabled") == true
                    pictureInPictureAutoEnter = call.argument<Boolean>("autoEnter") != false
                    updatePictureInPictureAspectRatio(call.argument<Double>("aspectRatio"))
                    result.success(null)
                }
                "enterPictureInPicture" -> {
                    updatePictureInPictureAspectRatio(call.argument<Double>("aspectRatio"))
                    result.success(enterPictureInPictureCompat())
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }

    private fun getActiveIpv4Cidr(): Map<String, Any>? {
        val connectivityManager =
            applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return null
        val activeNetwork = connectivityManager.activeNetwork ?: return null
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return null
        val isLocalNetwork =
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
        if (!isLocalNetwork) {
            return null
        }

        val linkProperties = connectivityManager.getLinkProperties(activeNetwork) ?: return null
        val linkAddress =
            linkProperties.linkAddresses.firstOrNull { link ->
                val address = link.address
                address is Inet4Address && !address.isLoopbackAddress
            } ?: return null

        return mapOf(
            "address" to linkAddress.address.hostAddress,
            "prefixLength" to linkAddress.prefixLength,
        )
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) {
            return
        }
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        multicastLock = wifiManager.createMulticastLock("ohome-discovery").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        val lock = multicastLock ?: return
        if (lock.isHeld) {
            lock.release()
        }
        multicastLock = null
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (!pictureInPictureEnabled || !pictureInPictureAutoEnter) {
            return
        }
        enterPictureInPictureCompat()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (!isInPictureInPictureMode) {
            pictureInPictureEnabled = false
        }
    }

    private fun enterPictureInPictureCompat(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        if (!pictureInPictureEnabled || isInPictureInPictureMode) {
            return false
        }
        return try {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(pictureInPictureAspectRatio)
                    .build(),
            )
        } catch (_: IllegalStateException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    private fun updatePictureInPictureAspectRatio(rawAspectRatio: Double?) {
        if (rawAspectRatio == null || rawAspectRatio <= 0.0 || !rawAspectRatio.isFinite()) {
            pictureInPictureAspectRatio = Rational(16, 9)
            return
        }
        val width = (rawAspectRatio * 1000).toInt().coerceIn(1, 100000)
        pictureInPictureAspectRatio = Rational(width, 1000)
    }
}
