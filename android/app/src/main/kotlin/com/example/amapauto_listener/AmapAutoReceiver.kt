package com.example.amapauto_listener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class AmapAutoReceiver(private val context: Context, private val channel: MethodChannel) : BroadcastReceiver() {
    private var lastNavigationData: Map<String, Any>? = null

    companion object {
        private const val TAG = "AmapAutoReceiver"
        // 高德地图的广播Action常量
        const val AMAPAUTO_ACTION = "AMAP_AUTO_NAVI"
        const val AMAPAUTO_NAVI_DATA_ACTION = "AMAP_AUTO_NAVI_DATA"
        const val AMAPAUTO_LOCATION_ACTION = "AMAP_AUTO_LOCATION"
        const val AMAPAUTO_NAVIGATION_ACTION = "AMAP_AUTO_NAVIGATION"
        const val AMAPAUTO_XMGD_NAVIGATOR = "XMGD_NAVIGATOR"
        const val AUTONAVI_STANDARD_BROADCAST = "AUTONAVI_STANDARD_BROADCAST_SEND"
    }

    // 注册广播接收器
    fun register() {
        try {
            val filter = IntentFilter().apply {
                addAction(AMAPAUTO_ACTION)
                addAction(AMAPAUTO_NAVI_DATA_ACTION)
                addAction(AMAPAUTO_LOCATION_ACTION)
                addAction(AMAPAUTO_NAVIGATION_ACTION)
                addAction(AMAPAUTO_XMGD_NAVIGATOR)
                addAction(AUTONAVI_STANDARD_BROADCAST)
            }
            context.registerReceiver(this, filter)
            Log.d(TAG, "广播接收器已注册")
        } catch (e: Exception) {
            Log.e(TAG, "注册广播接收器失败: ${e.message}", e)
        }
    }

    // 注销广播接收器
    fun unregister() {
        try {
            context.unregisterReceiver(this)
            Log.d(TAG, "广播接收器已注销")
        } catch (e: Exception) {
            Log.e(TAG, "注销广播接收器失败: ${e.message}", e)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "接收到广播: ${intent.action}")
        when (intent.action) {
            AMAPAUTO_ACTION -> {
                processNavigationData(intent)
            }
            AMAPAUTO_NAVI_DATA_ACTION -> {
                processNavigationData(intent)
            }
            AMAPAUTO_LOCATION_ACTION -> {
                processLocationData(intent)
            }
            AMAPAUTO_NAVIGATION_ACTION -> {
                processNavigationData(intent)
            }
            AMAPAUTO_XMGD_NAVIGATOR -> {
                processNavigationData(intent)
            }
            AUTONAVI_STANDARD_BROADCAST -> {
                Log.d(TAG, "接收到标准广播: ${intent.action}")
                processStandardBroadcast(intent)
            }
            else -> {
                Log.d(TAG, "接收到未知广播: ${intent.action}")
            }
        }
    }

    private fun processNavigationData(intent: Intent) {
        try {
            val data = parseNavigationData(intent)
            lastNavigationData = data

            channel.invokeMethod("onNavigationData", data)
            Log.d(TAG, "已发送导航数据: $data")
        } catch (e: Exception) {
            Log.e(TAG, "处理导航数据失败: ${e.message}", e)
            channel.invokeMethod("onError", mapOf(
                "error" to e.message,
                "stack" to e.stackTraceToString()
            ))
        }
    }

    private fun processLocationData(intent: Intent) {
        try {
            Log.d(TAG, "处理位置数据...")
            val data = parseLocationData(intent)

            channel.invokeMethod("onLocationData", data)
            Log.d(TAG, "已发送位置数据: $data")
        } catch (e: Exception) {
            Log.e(TAG, "处理位置数据失败: ${e.message}", e)
            channel.invokeMethod("onError", mapOf(
                "error" to e.message,
                "stack" to e.stackTraceToString()
            ))
        }
    }

    private fun processStandardBroadcast(intent: Intent) {
        try {
            val data = parseStandardBroadcast(intent)

            channel.invokeMethod("onStandardBroadcast", data)
            Log.d(TAG, "已发送标准广播数据: $data")
        } catch (e: Exception) {
            Log.e(TAG, "处理标准广播失败: ${e.message}", e)
            channel.invokeMethod("onError", mapOf(
                "error" to e.message,
                "stack" to e.stackTraceToString()
            ))
        }
    }

    private fun parseNavigationData(intent: Intent): Map<String, Any> {
        val data = mutableMapOf<String, Any>()
        val extras = intent.extras

        if (extras == null) {
            Log.d(TAG, "导航数据为空")
            return data
        }

        try {
            for (key in extras.keySet()) {
                extras.get(key)?.let { value ->
                    data[key] = value
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "解析导航数据失败: ${e.message}", e)
            throw e
        }

        return data
    }

    private fun parseLocationData(intent: Intent): Map<String, Any> {
        val data = mutableMapOf<String, Any>()
        val extras = intent.extras

        if (extras == null) {
            Log.d(TAG, "位置数据为空")
            return data
        }

        try {
            for (key in extras.keySet()) {
                extras.get(key)?.let { value ->
                    when (value) {
                        is Float -> data[key] = value
                        is Double -> data[key] = value
                        is Int -> data[key] = value
                        is Long -> data[key] = value
                        is String -> data[key] = value
                        else -> data[key] = value.toString()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "解析位置数据失败: ${e.message}", e)
            throw e
        }

        return data
    }

    private fun parseStandardBroadcast(intent: Intent): Map<String, Any> {
        val data = mutableMapOf<String, Any>()
        val extras = intent.extras

        if (extras == null) {
            Log.d(TAG, "标准广播数据为空")
            return data
        }

        try {
            for (key in extras.keySet()) {
                extras.get(key)?.let { value ->
                    data[key] = when (value) {
                        is Float -> value
                        is Double -> value
                        is Int -> value
                        is Long -> value
                        is String -> value
                        else -> value.toString()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "解析标准广播数据失败: ${e.message}", e)
            throw e
        }

        return data
    }

    private fun createEmptyNavData(): Map<String, Any> {
        return mutableMapOf(
            "error" to "数据为空",
            "timestamp" to System.currentTimeMillis()
        )
    }

    // 供外部调用的公共方法
    fun getLastNavigationData(): Map<String, Any>? {
        return lastNavigationData
    }

    fun getListeningActions(): List<String> {
        return listOf(
            AMAPAUTO_ACTION,
            AMAPAUTO_NAVI_DATA_ACTION,
            AMAPAUTO_LOCATION_ACTION,
            AMAPAUTO_NAVIGATION_ACTION,
            AMAPAUTO_XMGD_NAVIGATOR,
            AUTONAVI_STANDARD_BROADCAST
        )
    }
}