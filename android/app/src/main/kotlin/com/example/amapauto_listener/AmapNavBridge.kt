package com.example.amapauto_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.util.Log

/**
 * 与 Flutter 侧桥接：
 * - EventChannel: "amap_nav_stream" 推送广播解析后的数据
 * - MethodChannel: "amap_nav" 控制动态注册/反注册
 *
 * Android 14+ (API 34+) 兼容：
 * - registerReceiver 必须使用 RECEIVER_EXPORTED / RECEIVER_NOT_EXPORTED
 * - 自定义隐式广播的静态 manifest 接收器可能受限，优先使用动态注册
 * - sendBroadcast 需用显式 Intent (setPackage) + FLAG_RECEIVER_EXPORTED
 *
 * 遵循 AmapAuto 标准广播协议字段命名
 */
object AmapNavBridge : EventChannel.StreamHandler, MethodChannel.MethodCallHandler {

    private const val EVENT_CHANNEL = "amap_nav_stream"
    private const val METHOD_CHANNEL = "amap_nav"
    private const val TAG = "AmapNavBridge"

    private var context: Context? = null
    private var eventSink: EventChannel.EventSink? = null
    private var dynamicReceiver: BroadcastReceiver? = null
    private var lastEvent: Map<String, Any?>? = null

    // 可运行时配置的 Action 列表
    private var actions: MutableSet<String> = mutableSetOf(
        "AUTONAVI_STANDARD_BROADCAST_SEND",
        "AUTONAVI_STANDARD_BROADCAST_RECV"
    )

    fun setup(messenger: BinaryMessenger, appContext: Context) {
        context = appContext.applicationContext

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
    }

    fun postEvent(map: Map<String, Any?>) {
        lastEvent = map
        Log.d(TAG, "postEvent: $map")
        eventSink?.success(map)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "onListen: Flutter subscribed, replaying lastEvent=${lastEvent != null}")
        lastEvent?.let {
            events?.success(it)
        }
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "onCancel: Flutter unsubscribed")
        eventSink = null
    }

    // ═════════════════════════════════════════════════════════════
    // 发送广播 — Android 14+ 必须用显式 Intent
    // ═════════════════════════════════════════════════════════════
    private fun sendBroadcasts(payload: Map<String, Any?>) {
        val ctx = context ?: run {
            Log.w(TAG, "sendBroadcasts: context is null")
            return
        }
        val packageName = ctx.packageName

        fun makeIntent(action: String, withCategory: Boolean): Intent {
            val it = Intent(action)
            // Android 14+：显式指定目标包名，避免隐式广播被拦截
            it.setPackage(packageName)
            if (withCategory) it.addCategory("AUTONAVI_STANDARD_CATEGORY")
            // 确保能送达本应用的所有组件（包括 stopped state）
            it.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)

            // 标准协议字段写入 extras
            fun putString(key: String) {
                (payload[key] as? String)?.let { v -> it.putExtra(key, v) }
            }
            fun putInt(key: String) {
                (payload[key] as? Int)?.let { v -> it.putExtra(key, v) }
            }
            putString("KEY_ACTION")
            putString("CUR_ROAD_NAME")
            putString("NEXT_ROAD_NAME")
            putInt("ROUTE_REMAIN_DIS")
            putInt("ROUTE_REMAIN_TIME")
            putInt("CUR_SPEED")
            putInt("LIMITED_SPEED")
            putInt("ICON")
            putInt("KEY_TYPE")

            // 透传其他字段
            payload.forEach { (k, v) ->
                if (k !in setOf("KEY_ACTION", "CUR_ROAD_NAME", "NEXT_ROAD_NAME",
                        "ROUTE_REMAIN_DIS", "ROUTE_REMAIN_TIME", "CUR_SPEED",
                        "LIMITED_SPEED", "ICON", "KEY_TYPE")) {
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

        // 发送到 SEND 和 RECV 两个 action，各有带/不带 category 两种
        val actionList = listOf("AUTONAVI_STANDARD_BROADCAST_SEND", "AUTONAVI_STANDARD_BROADCAST_RECV")
        actionList.forEach { act ->
            try {
                val i1 = makeIntent(act, true)
                val i2 = makeIntent(act, false)
                Log.d(TAG, "sendBroadcasts: sending action=$act withCategory")
                ctx.sendBroadcast(i1)
                Log.d(TAG, "sendBroadcasts: sending action=$act noCategory")
                ctx.sendBroadcast(i2)
            } catch (e: Exception) {
                Log.e(TAG, "sendBroadcasts failed for $act: ${e.message}", e)
            }
        }
    }

    // ═════════════════════════════════════════════════════════════
    // 动态接收器 — 提取标准协议字段
    // ═════════════════════════════════════════════════════════════
    private fun createDynamicReceiver(): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                try {
                    val act = intent?.action
                    Log.d(TAG, "dynamicReceiver onReceive: action=$act")
                    if (act != null && actions.contains(act)) {
                        val data = parseIntent(intent)
                        postEvent(data)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "dynamicReceiver error: ${e.message}", e)
                }
            }
        }
    }

    private fun parseIntent(intent: Intent): Map<String, Any?> {
        val data = HashMap<String, Any?>()

        fun s(key: String, vararg fallbacks: String): String? {
            val v = intent.getStringExtra(key)
            if (v != null) return v
            for (fb in fallbacks) {
                val fv = intent.getStringExtra(fb)
                if (fv != null) return fv
            }
            return null
        }
        fun i(key: String, vararg fallbacks: String): Int? {
            if (intent.hasExtra(key)) {
                val v = intent.getIntExtra(key, -1)
                if (v != -1) return v
            }
            for (fb in fallbacks) {
                if (intent.hasExtra(fb)) {
                    val v = intent.getIntExtra(fb, -1)
                    if (v != -1) return v
                }
            }
            return null
        }
        fun d(key: String, vararg fallbacks: String): Double? {
            if (intent.hasExtra(key)) return intent.getDoubleExtra(key, -999.0).takeIf { it != -999.0 }
            for (fb in fallbacks) {
                if (intent.hasExtra(fb)) return intent.getDoubleExtra(fb, -999.0).takeIf { it != -999.0 }
            }
            return null
        }

        // 标准协议字段
        data["KEY_TYPE"] = i("KEY_TYPE", "keyType", "type")
        data["KEY_ACTION"] = s("KEY_ACTION", "keyAction", "action")
        data["CUR_ROAD_NAME"] = s("CUR_ROAD_NAME", "curRoadName", "EXTRA_ROAD_NAME", "roadName")
        data["NEXT_ROAD_NAME"] = s("NEXT_ROAD_NAME", "nextRoadName", "EXTRA_NEXT_ROAD_NAME", "nextRoad")
        data["ROUTE_REMAIN_DIS"] = i("ROUTE_REMAIN_DIS", "routeRemainDis", "EXTRA_REMAIN_DISTANCE", "remainDistance")
        data["ROUTE_REMAIN_TIME"] = i("ROUTE_REMAIN_TIME", "routeRemainTime", "EXTRA_REMAIN_TIME", "remainTime")
        data["CUR_SPEED"] = i("CUR_SPEED", "curSpeed", "EXTRA_CUR_SPEED", "speed")
        data["LIMITED_SPEED"] = i("LIMITED_SPEED", "limitSpeed", "EXTRA_LIMIT_SPEED", "limitSpeed")
        data["ICON"] = i("ICON", "icon", "turnIcon")
        data["EXTRA_STATE"] = i("EXTRA_STATE", "extraState", "status", "navStatus")
        data["SEG_REMAIN_DIS"] = i("SEG_REMAIN_DIS", "segRemainDis")
        data["SEG_REMAIN_TIME"] = i("SEG_REMAIN_TIME", "segRemainTime")
        data["ROUTE_ALL_DIS"] = i("ROUTE_ALL_DIS", "routeAllDis", "totalDistance")
        data["ROUTE_ALL_TIME"] = i("ROUTE_ALL_TIME", "routeAllTime", "totalTime")
        data["CAR_LATITUDE"] = d("CAR_LATITUDE", "carLatitude", "latitude", "lat")
        data["CAR_LONGITUDE"] = d("CAR_LONGITUDE", "carLongitude", "longitude", "lng", "lon")
        data["CAR_DIRECTION"] = i("CAR_DIRECTION", "carDirection", "direction", "bearing")
        data["SAPA_DIST"] = i("SAPA_DIST", "sapaDist")
        data["SAPA_NAME"] = s("SAPA_NAME", "sapaName")
        data["SAPA_TYPE"] = i("SAPA_TYPE", "sapaType")
        data["SAPA_NUM"] = i("SAPA_NUM", "sapaNum")
        data["CAMERA_DIST"] = i("CAMERA_DIST", "cameraDist")
        data["CAMERA_TYPE"] = i("CAMERA_TYPE", "cameraType")
        data["CAMERA_SPEED"] = i("CAMERA_SPEED", "cameraSpeed")
        data["ROAD_TYPE"] = i("ROAD_TYPE", "roadType")
        data["TRAFFIC_LIGHT_NUM"] = i("TRAFFIC_LIGHT_NUM", "trafficLightNum")
        data["ROUND_ABOUT_NUM"] = i("ROUND_ABOUT_NUM", "roundAboutNum")
        data["ROUND_ALL_NUM"] = i("ROUND_ALL_NUM", "roundAllNum")
        data["NEXT_NEXT_ROAD_NAME"] = s("NEXT_NEXT_ROAD_NAME", "nextNextRoadName")
        data["NEXT_NEXT_TURN_ICON"] = i("NEXT_NEXT_TURN_ICON", "nextNextTurnIcon")
        data["NEXT_SEG_REMAIN_DIS"] = i("NEXT_SEG_REMAIN_DIS", "nextSegRemainDis")
        data["NEW_ICON"] = i("NEW_ICON", "newIcon", "new_icon")

        // 透传所有未被显式处理的 extras
        val handledKeys = data.keys.toSet()
        intent.extras?.keySet()?.forEach { k ->
            if (!handledKeys.contains(k)) {
                val v = intent.extras?.get(k)
                when (v) {
                    is String, is Int, is Long, is Boolean, is Float, is Double -> data[k] = v
                }
            }
        }

        Log.d(TAG, "parsedIntent: ${data.size} fields, keys=${data.keys}")
        return data
    }

    // ═════════════════════════════════════════════════════════════
    // 注册/反注册 — Android 14+ 必须用 RECEIVER_EXPORTED
    // ═════════════════════════════════════════════════════════════
    @Suppress("DEPRECATION")
    private fun registerReceiverSafe(ctx: Context, receiver: BroadcastReceiver, filter: IntentFilter) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34+
                // Android 14+：必须显式声明导出行为；接收外部广播用 EXPORTED
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                Log.d(TAG, "registerReceiver: RECEIVER_EXPORTED (API 34+)")
            } else {
                // API < 34 使用旧 API
                ctx.registerReceiver(receiver, filter)
                Log.d(TAG, "registerReceiver: legacy API")
            }
        } catch (e: Exception) {
            Log.e(TAG, "registerReceiver failed: ${e.message}", e)
            throw e
        }
    }

    private fun unregisterReceiverSafe(ctx: Context, receiver: BroadcastReceiver?) {
        if (receiver == null) return
        try {
            ctx.unregisterReceiver(receiver)
            Log.d(TAG, "unregisterReceiver: success")
        } catch (e: Exception) {
            Log.w(TAG, "unregisterReceiver failed (may already be unregistered): ${e.message}")
        }
    }

    private fun doRegister() {
        val ctx = context ?: run {
            Log.w(TAG, "doRegister: context is null")
            return
        }

        if (dynamicReceiver != null) {
            Log.d(TAG, "doRegister: already registered, re-registering")
            unregisterReceiverSafe(ctx, dynamicReceiver)
        }

        dynamicReceiver = createDynamicReceiver()

        // 过滤器 1：带 Category — 用于接收高德官方标准广播
        val f1 = IntentFilter().apply {
            priority = 1000
            actions.forEach { addAction(it) }
            addCategory("AUTONAVI_STANDARD_CATEGORY")
        }

        // 过滤器 2：仅 Action — 提升兼容性（有些实现可能不带 Category）
        val f2 = IntentFilter().apply {
            priority = 1000
            actions.forEach { addAction(it) }
        }

        try {
            registerReceiverSafe(ctx, dynamicReceiver!!, f1)
            Log.d(TAG, "Registered filter with category for: $actions")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register with category: ${e.message}")
        }

        try {
            registerReceiverSafe(ctx, dynamicReceiver!!, f2)
            Log.d(TAG, "Registered filter without category for: $actions")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register without category: ${e.message}")
        }
    }

    // ═════════════════════════════════════════════════════════════
    // MethodChannel 处理
    // ═════════════════════════════════════════════════════════════
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startNavigationListener" -> {
                Log.d(TAG, "startNavigationListener called")
                try {
                    doRegister()
                    // 回发初始状态到 Flutter
                    eventSink?.success(mapOf(
                        "KEY_TYPE" to -1,
                        "KEY_ACTION" to "service_ready",
                        "message" to "动态接收器已注册，等待高德地图广播",
                        "timestamp" to System.currentTimeMillis()
                    ))
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "startNavigationListener failed: ${e.message}", e)
                    result.error("REGISTER_FAILED", e.message, null)
                }
            }

            "stopNavigationListener" -> {
                Log.d(TAG, "stopNavigationListener called")
                try {
                    val ctx = context
                    if (ctx != null) {
                        unregisterReceiverSafe(ctx, dynamicReceiver)
                    }
                    dynamicReceiver = null
                } catch (e: Exception) {
                    Log.w(TAG, "stopNavigationListener error: ${e.message}")
                }
                result.success(null)
            }

            "sendTestBroadcast" -> {
                Log.d(TAG, "sendTestBroadcast called")
                val sample = mapOf<String, Any>(
                    "KEY_TYPE" to 10001,
                    "KEY_ACTION" to "turn-left",
                    "CUR_ROAD_NAME" to "人民路",
                    "NEXT_ROAD_NAME" to "解放路",
                    "ROUTE_REMAIN_DIS" to 850,
                    "ROUTE_REMAIN_TIME" to 120,
                    "CUR_SPEED" to 38,
                    "LIMITED_SPEED" to 60,
                    "ICON" to 2,
                    "ROAD_TYPE" to 3,
                    "SEG_REMAIN_DIS" to 500,
                    "SEG_REMAIN_TIME" to 80
                )
                try {
                    // 先直接 post 一份数据给 Flutter（确保即使 sendBroadcast 失败也有数据）
                    val directData = HashMap<String, Any?>()
                    sample.forEach { (k, v) -> directData[k] = v }
                    directData["_source"] = "test_direct"
                    postEvent(directData)
                    // 再通过广播机制发送
                    sendBroadcasts(sample)
                } catch (e: Exception) {
                    Log.e(TAG, "sendTestBroadcast error: ${e.message}", e)
                    result.error("SEND_FAILED", e.message, null)
                    return
                }
                result.success(true)
            }

            "sendBroadcast" -> {
                val args = call.arguments
                val map = (args as? Map<*, *>)?.mapNotNull { (k, v) ->
                    (k as? String)?.let { it to v }
                }?.toMap() ?: emptyMap()
                Log.d(TAG, "sendBroadcast: $map")
                try {
                    sendBroadcasts(map)
                } catch (e: Exception) {
                    Log.e(TAG, "sendBroadcast error: ${e.message}", e)
                    result.error("SEND_FAILED", e.message, null)
                    return
                }
                result.success(null)
            }

            "setActions" -> {
                val args = call.arguments
                val list = (args as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
                Log.d(TAG, "setActions: $list")
                actions.clear()
                actions.addAll(list.ifEmpty {
                    listOf(
                        "AUTONAVI_STANDARD_BROADCAST_SEND",
                        "AUTONAVI_STANDARD_BROADCAST_RECV"
                    )
                })

                // 如果动态接收器已存在，重新注册以应用新的 Actions
                if (dynamicReceiver != null) {
                    val ctx = context ?: return
                    unregisterReceiverSafe(ctx, dynamicReceiver)
                    dynamicReceiver = null
                    doRegister()
                }
                result.success(null)
            }

            "getStatus" -> {
                // 新增：让 Flutter 侧查询当前状态
                result.success(mapOf(
                    "registered" to (dynamicReceiver != null),
                    "actions" to actions.toList(),
                    "hasLastEvent" to (lastEvent != null),
                    "apiLevel" to Build.VERSION.SDK_INT,
                    "packageName" to (context?.packageName ?: "unknown")
                ))
            }

            else -> result.notImplemented()
        }
    }
}