package com.example.amapauto_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.util.Log

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
    private var lastEvent: Map<String, Any?>? = null

    private fun sendBroadcasts(payload: Map<String, Any?>) {
        val ctx = context ?: return
        fun makeIntent(action: String, withCategory: Boolean): Intent {
            val it = Intent(action)
            if (withCategory) it.addCategory("AUTONAVI_STANDARD_CATEGORY")
            // 常用键写入 extras（保留原样，若没有传入则忽略）
            fun putString(key: String) { (payload[key] as? String)?.let { v -> it.putExtra(key, v) } }
            fun putInt(key: String) { (payload[key] as? Int)?.let { v -> it.putExtra(key, v) } }
            putString("KEY_ACTION")
            putString("EXTRA_ROAD_NAME")
            putString("EXTRA_NEXT_ROAD_NAME")
            putInt("EXTRA_REMAIN_DISTANCE")
            putInt("EXTRA_REMAIN_TIME")
            putInt("EXTRA_CUR_SPEED")
            putInt("EXTRA_LIMIT_SPEED")
            // 允许透传任意额外键
            payload.forEach { (k, v) ->
                if (k !in setOf("KEY_ACTION","EXTRA_ROAD_NAME","EXTRA_NEXT_ROAD_NAME","EXTRA_REMAIN_DISTANCE","EXTRA_REMAIN_TIME","EXTRA_CUR_SPEED","EXTRA_LIMIT_SPEED")) {
                    when (v) {
                        is String -> it.putExtra(k, v)
                        is Int -> it.putExtra(k, v)
                        is Long -> it.putExtra(k, v)
                        is Boolean -> it.putExtra(k, v)
                        is Float -> it.putExtra(k, v)
                        is Double -> it.putExtra(k, v.toFloat())
                    }
                }
            }
            return it
        }
        val actions = listOf("AUTONAVI_STANDARD_BROADCAST_SEND","AUTONAVI_STANDARD_BROADCAST_RECV")
        actions.forEach { act ->
            val i1 = makeIntent(act, true)
            val i2 = makeIntent(act, false)
            Log.d("AmapNavBridge", "sendBroadcasts: action=$act withCategory extras=${i1.extras}")
            ctx.sendBroadcast(i1)
            Log.d("AmapNavBridge", "sendBroadcasts: action=$act noCategory extras=${i2.extras}")
            ctx.sendBroadcast(i2)
        }
    }

    fun setup(messenger: BinaryMessenger, appContext: Context) {
        context = appContext.applicationContext

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
    }

    fun postEvent(map: Map<String, Any?>) {
        lastEvent = map
        Log.d("AmapNavBridge", "postEvent: $map")
        eventSink?.success(map)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // 订阅建立时立刻补发最近一次事件，避免首条丢失
        lastEvent?.let {
            Log.d("AmapNavBridge", "replay lastEvent on listen")
            events?.success(it)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startNavigationListener" -> {
                // 可选：动态注册（与 Manifest 静态注册互补）
                if (dynamicReceiver == null) {
                    val actions = listOf(
                        "AUTONAVI_STANDARD_BROADCAST_SEND",
                        "AUTONAVI_STANDARD_BROADCAST_RECV"
                    )
                    dynamicReceiver = object : BroadcastReceiver() {
                        override fun onReceive(ctx: Context?, intent: Intent?) {
                            val act = intent?.action
                            if (act != null && actions.contains(act)) {
                                Log.d("AmapNavBridge", "dynamic onReceive: $act extras=${intent.extras}")
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
                    // 过滤器1：带 Category
                    val f1 = IntentFilter().apply {
                        priority = 1000
                        actions.forEach { addAction(it) }
                        addCategory("AUTONAVI_STANDARD_CATEGORY")
                    }
                    // 过滤器2：仅 Action，不带 Category，提升兼容性
                    val f2 = IntentFilter().apply {
                        priority = 1000
                        actions.forEach { addAction(it) }
                    }
                    context?.registerReceiver(dynamicReceiver, f1)
                    context?.registerReceiver(dynamicReceiver, f2)
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
            "sendTestBroadcast" -> {
                val sample = mapOf(
                    "KEY_ACTION" to "turn-left",
                    "EXTRA_ROAD_NAME" to "人民路",
                    "EXTRA_NEXT_ROAD_NAME" to "解放路",
                    "EXTRA_REMAIN_DISTANCE" to 850,
                    "EXTRA_REMAIN_TIME" to 120,
                    "EXTRA_CUR_SPEED" to 38,
                    "EXTRA_LIMIT_SPEED" to 60
                )
                sendBroadcasts(sample)
                result.success(null)
            }
            "sendBroadcast" -> {
                val args = call.arguments
                val map = (args as? Map<*, *>)?.mapNotNull { (k,v) ->
                    (k as? String)?.let { it to v }
                }?.toMap() ?: emptyMap()
                sendBroadcasts(map)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}