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

            // 常见字段键名（不同系统版本可能存在差异，尽量容错）
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

            // 透传 extras 中的其他字段（例如：EXTRA_DAY_NIGHT_MODE 等）
            intent.extras?.keySet()?.forEach { k ->
                if (!data.containsKey(k)) {
                    val v = intent.extras?.get(k)
                    when (v) {
                        is String, is Int, is Long, is Boolean, is Float, is Double -> data[k] = v
                    }
                }
            }

            AmapNavBridge.postEvent(data)
        }
    }
}