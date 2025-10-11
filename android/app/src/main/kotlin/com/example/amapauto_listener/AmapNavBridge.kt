package com.example.amapauto_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 与 Flutter 侧桥接：
 * - EventChannel: "amap_nav_stream" 推送广播解析后的数据
 * - MethodChannel: "amap_nav" 控制动态注册/反注册（可选，静态注册已能收到）
 *
 * 在 MainActivity.configureFlutterEngine 中调用 setup(...)
 */
object AmapNavBridge : EventChannel.StreamHandler, MethodChannel.MethodCallHandler {

    private const val EVENT_CHANNEL = "amap_nav_stream"
    private const val METHOD_CHANNEL = "amap_nav"

    private var context: Context? = null
    private var eventSink: EventChannel.EventSink? = null
    private var dynamicReceiver: BroadcastReceiver? = null

    fun setup(messenger: BinaryMessenger, appContext: Context) {
        context = appContext.applicationContext

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
    }

    fun postEvent(map: Map<String, Any?>) {
        eventSink?.success(map)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startNavigationListener" -> {
                // 可选：动态注册（与 Manifest 静态注册互补）
                if (dynamicReceiver == null) {
                    dynamicReceiver = object : BroadcastReceiver() {
                        override fun onReceive(ctx: Context?, intent: Intent?) {
                            if (intent?.action == "AUTONAVI_STANDARD_BROADCAST_SEND") {
                                val data = HashMap<String, Any?>()
                                fun s(key: String): String? = intent.getStringExtra(key)
                                fun i(key: String): Int? = if (intent.hasExtra(key)) intent.getIntExtra(key, -1) else null

                                data["type"] = i("KEY_TYPE")
                                data["action"] = s("KEY_ACTION")
                                data["roadName"] = s("EXTRA_ROAD_NAME")
                                data["nextRoadName"] = s("EXTRA_NEXT_ROAD_NAME")
                                data["remainDistance"] = i("EXTRA_REMAIN_DISTANCE")
                                data["remainTime"] = i("EXTRA_REMAIN_TIME")
                                data["curSpeed"] = i("EXTRA_CUR_SPEED")
                                data["limitSpeed"] = i("EXTRA_LIMIT_SPEED")

                                postEvent(data)
                            }
                        }
                    }
                    val f = IntentFilter("AUTONAVI_STANDARD_BROADCAST_SEND").apply {
                        addCategory("AUTONAVI_STANDARD_CATEGORY")
                    }
                    context?.registerReceiver(dynamicReceiver, f)
                }
                result.success(null)
            }
            "stopNavigationListener" -> {
                dynamicReceiver?.let {
                    runCatching { context?.unregisterReceiver(it) }
                }
                dynamicReceiver = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}