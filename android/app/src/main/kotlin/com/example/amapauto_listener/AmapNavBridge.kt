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
 * 遵循 AmapAuto 标准广播协议字段命名
 * 在 MainActivity.configureFlutterEngine 中调用 setup(...)
 */
object AmapNavBridge : EventChannel.StreamHandler, MethodChannel.MethodCallHandler {

    private const val EVENT_CHANNEL = "amap_nav_stream"
    private const val METHOD_CHANNEL = "amap_nav"

    private var context: Context? = null
    private var eventSink: EventChannel.EventSink? = null
    private var dynamicReceiver: BroadcastReceiver? = null
    private var lastEvent: Map<String, Any?>? = null
    // 可运行时配置的 Action 列表，默认含 SEND/RECV
    private var actions: MutableSet<String> = mutableSetOf(
        "AUTONAVI_STANDARD_BROADCAST_SEND",
        "AUTONAVI_STANDARD_BROADCAST_RECV"
    )

    private fun sendBroadcasts(payload: Map<String, Any?>) {
        val ctx = context ?: return
        fun makeIntent(action: String, withCategory: Boolean): Intent {
            val it = Intent(action)
            if (withCategory) it.addCategory("AUTONAVI_STANDARD_CATEGORY")
            it.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
            // 标准协议字段写入 extras
            fun putString(key: String) { (payload[key] as? String)?.let { v -> it.putExtra(key, v) } }
            fun putInt(key: String) { (payload[key] as? Int)?.let { v -> it.putExtra(key, v) } }
            putString("KEY_ACTION")
            putString("CUR_ROAD_NAME")
            putString("NEXT_ROAD_NAME")
            putInt("ROUTE_REMAIN_DIS")
            putInt("ROUTE_REMAIN_TIME")
            putInt("CUR_SPEED")
            putInt("LIMITED_SPEED")
            putInt("ICON")
            // 允许透传任意额外键
            payload.forEach { (k, v) ->
                if (k !in setOf("KEY_ACTION","CUR_ROAD_NAME","NEXT_ROAD_NAME","ROUTE_REMAIN_DIS","ROUTE_REMAIN_TIME","CUR_SPEED","LIMITED_SPEED","ICON")) {
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

    // 构建动态接收器：提取标准协议字段 + 旧字段回退
    private fun createDynamicReceiver(): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val act = intent?.action
                if (act != null && actions.contains(act)) {
                    Log.d("AmapNavBridge", "dynamic onReceive: $act extras=${intent.extras}")
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
                        if (intent.hasExtra(key)) return intent.getIntExtra(key, -1)
                        for (fb in fallbacks) {
                            if (intent.hasExtra(fb)) return intent.getIntExtra(fb, -1)
                        }
                        return null
                    }

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
                    data["CAR_LATITUDE"] = if (intent.hasExtra("CAR_LATITUDE")) intent.getDoubleExtra("CAR_LATITUDE", 0.0) else null
                    data["CAR_LONGITUDE"] = if (intent.hasExtra("CAR_LONGITUDE")) intent.getDoubleExtra("CAR_LONGITUDE", 0.0) else null
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

                    // 透传所有 extras，避免遗漏协议字段
                    val handledKeys = data.keys.toSet()
                    intent.extras?.keySet()?.forEach { k ->
                        if (!handledKeys.contains(k)) {
                            val v = intent.extras?.get(k)
                            when (v) {
                                is String, is Int, is Long, is Boolean, is Float, is Double -> data[k] = v
                            }
                        }
                    }
                    postEvent(data)
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startNavigationListener" -> {
                // 动态注册（与 Manifest 静态注册互补）
                if (dynamicReceiver == null) {
                    dynamicReceiver = createDynamicReceiver()
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
                    "CUR_ROAD_NAME" to "人民路",
                    "NEXT_ROAD_NAME" to "解放路",
                    "ROUTE_REMAIN_DIS" to 850,
                    "ROUTE_REMAIN_TIME" to 120,
                    "CUR_SPEED" to 38,
                    "LIMITED_SPEED" to 60,
                    "ICON" to 2
                )
                sendBroadcasts(sample)
                result.success(null)
            }
            "sendBroadcast" -> {
                val args = call.arguments
                val map = (args as? Map<*, *>)?.mapNotNull { (k, v) ->
                    (k as? String)?.let { it to v }
                }?.toMap() ?: emptyMap()
                sendBroadcasts(map)
                result.success(null)
            }
            "setActions" -> {
                val args = call.arguments
                val list = (args as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
                Log.d("AmapNavBridge", "setActions: $list")
                actions.clear()
                actions.addAll(list.ifEmpty {
                    listOf(
                        "AUTONAVI_STANDARD_BROADCAST_SEND",
                        "AUTONAVI_STANDARD_BROADCAST_RECV"
                    )
                })

                // 如果动态接收器已存在，重新注册以应用新的Actions
                val currentReceiver = dynamicReceiver
                if (currentReceiver != null) {
                    runCatching { context?.unregisterReceiver(currentReceiver) }

                    dynamicReceiver = createDynamicReceiver()

                    // 重新注册过滤器
                    val f1 = IntentFilter().apply {
                        priority = 1000
                        actions.forEach { addAction(it) }
                        addCategory("AUTONAVI_STANDARD_CATEGORY")
                    }
                    val f2 = IntentFilter().apply {
                        priority = 1000
                        actions.forEach { addAction(it) }
                    }
                    context?.registerReceiver(dynamicReceiver, f1)
                    context?.registerReceiver(dynamicReceiver, f2)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}