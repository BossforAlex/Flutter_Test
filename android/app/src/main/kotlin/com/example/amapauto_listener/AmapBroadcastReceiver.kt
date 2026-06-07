package com.example.amapauto_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 静态注册的高德标准广播接收器
 * 动作：AUTONAVI_STANDARD_BROADCAST_SEND
 * 类别：AUTONAVI_STANDARD_CATEGORY
 * 收到后将关键信息提取并转发给 AmapNavBridge 推送到 Flutter
 *
 * 遵循 AmapAuto 标准广播协议字段命名：
 *   KEY_TYPE, CUR_ROAD_NAME, NEXT_ROAD_NAME, ROUTE_REMAIN_DIS, ROUTE_REMAIN_TIME,
 *   CUR_SPEED, LIMITED_SPEED, ICON, KEY_ACTION, EXTRA_STATE 等
 * 同时兼容旧字段名（EXTRA_ROAD_NAME, EXTRA_REMAIN_DISTANCE 等）作为回退
 */
class AmapBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) return
        val actions = setOf(
            "AUTONAVI_STANDARD_BROADCAST_SEND",
            "AUTONAVI_STANDARD_BROADCAST_RECV"
        )
        val act = intent.action
        if (act != null && actions.contains(act)) {
            Log.d("AmapBroadcastReceiver", "onReceive: $act extras=${intent.extras}")
            val data = HashMap<String, Any?>()

            // 辅助函数：优先读取标准协议字段，回退到旧字段名
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

            // 标准协议字段 + 旧字段回退
            data["KEY_TYPE"] = i("KEY_TYPE", "keyType", "type")
            data["KEY_ACTION"] = s("KEY_ACTION", "keyAction", "action")

            // 当前道路：CUR_ROAD_NAME（标准） / EXTRA_ROAD_NAME（旧）
            data["CUR_ROAD_NAME"] = s("CUR_ROAD_NAME", "curRoadName", "EXTRA_ROAD_NAME", "roadName")
            // 下一道路：NEXT_ROAD_NAME（标准） / EXTRA_NEXT_ROAD_NAME（旧）
            data["NEXT_ROAD_NAME"] = s("NEXT_ROAD_NAME", "nextRoadName", "EXTRA_NEXT_ROAD_NAME", "nextRoad")

            // 剩余距离：ROUTE_REMAIN_DIS（标准，米） / EXTRA_REMAIN_DISTANCE（旧）
            data["ROUTE_REMAIN_DIS"] = i("ROUTE_REMAIN_DIS", "routeRemainDis", "EXTRA_REMAIN_DISTANCE", "remainDistance")
            // 剩余时间：ROUTE_REMAIN_TIME（标准，秒） / EXTRA_REMAIN_TIME（旧）
            data["ROUTE_REMAIN_TIME"] = i("ROUTE_REMAIN_TIME", "routeRemainTime", "EXTRA_REMAIN_TIME", "remainTime")

            // 当前速度：CUR_SPEED（标准，km/h） / EXTRA_CUR_SPEED（旧）
            data["CUR_SPEED"] = i("CUR_SPEED", "curSpeed", "EXTRA_CUR_SPEED", "speed")
            // 限速：LIMITED_SPEED（标准，km/h） / EXTRA_LIMIT_SPEED（旧）
            data["LIMITED_SPEED"] = i("LIMITED_SPEED", "limitSpeed", "EXTRA_LIMIT_SPEED", "limitSpeed")

            // 转向图标：ICON（标准）
            data["ICON"] = i("ICON", "icon", "turnIcon")

            // 导航状态：EXTRA_STATE（标准）
            data["EXTRA_STATE"] = i("EXTRA_STATE", "extraState", "status", "navStatus")

            // 其他协议字段
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

            // 透传 extras 中未被显式处理的字段（排除已处理的键）
            val handledKeys = data.keys.toSet()
            intent.extras?.keySet()?.forEach { k ->
                if (!handledKeys.contains(k)) {
                    val v = intent.extras?.get(k)
                    when (v) {
                        is String, is Int, is Long, is Boolean, is Float, is Double -> {
                            data[k] = v
                        }
                    }
                }
            }

            AmapNavBridge.postEvent(data)
        }
    }
}