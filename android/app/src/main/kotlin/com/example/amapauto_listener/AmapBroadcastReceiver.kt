package com.example.amapauto_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * 静态注册的高德标准广播接收器
 *
 * Android 14+ (API 34+) 重要说明：
 * - 对于从其他应用发来的自定义隐式广播，静态接收器可能收不到。
 * - 因此主要的数据接收依赖 AmapNavBridge 中的动态注册（context-registered receiver）。
 * - 此静态接收器作为补充/回退方案。
 *
 * 监听 Actions: AUTONAVI_STANDARD_BROADCAST_SEND / RECV
 * 遵循 AmapAuto 标准广播协议字段命名
 */
class AmapBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AmapBroadcastRcv"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) return
        val actions = setOf(
            "AUTONAVI_STANDARD_BROADCAST_SEND",
            "AUTONAVI_STANDARD_BROADCAST_RECV"
        )
        val act = intent.action
        if (act != null && actions.contains(act)) {
            Log.d(TAG, "onReceive: $act supplied=true api=${Build.VERSION.SDK_INT}")
            val data = parseIntent(intent)
            AmapNavBridge.postEvent(data)
            Log.d(TAG, "posted ${data.size} fields to bridge")
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

        // 透传未被显式处理的 extras
        val handledKeys = data.keys.toSet()
        intent.extras?.keySet()?.forEach { k ->
            if (!handledKeys.contains(k)) {
                val v = intent.extras?.get(k)
                when (v) {
                    is String, is Int, is Long, is Boolean, is Float, is Double -> data[k] = v
                }
            }
        }
        return data
    }
}