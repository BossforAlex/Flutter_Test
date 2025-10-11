package com.example.amapauto_listener

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * 高德地图广播测试助手类
 * 用于模拟高德地图广播数据，便于调试和测试
 */
class AmapAutoTestHelper(private val context: Context) {
    companion object {
        private const val TAG = "AmapAutoTestHelper"
        
        // 测试数据常量
        const val TEST_LATITUDE = 39.9042
        const val TEST_LONGITUDE = 116.4074
        const val TEST_SPEED = 60.0
        const val TEST_BEARING = 90.0
        const val TEST_ACCURACY = 10.0
        const val TEST_DISTANCE = 1500
        const val TEST_TIME = 300
        const val TEST_NEXT_TURN = "右转"
        const val TEST_NEXT_ROAD = "中山路"
    }

    /**
     * 发送模拟的导航数据广播
     */
    fun sendTestNavigationData() {
        try {
            val intent = Intent(AmapAutoReceiver.AMAPAUTO_NAVI_DATA_ACTION)
            val bundle = Bundle().apply {
                putString("action", "navigation")
                putLong("timestamp", System.currentTimeMillis())
                putInt("route_distance", TEST_DISTANCE)
                putInt("route_time", TEST_TIME)
                putDouble("current_speed", TEST_SPEED)
                putString("next_turn", TEST_NEXT_TURN)
                putString("next_road", TEST_NEXT_ROAD)
                putDouble("latitude", TEST_LATITUDE)
                putDouble("longitude", TEST_LONGITUDE)
                putDouble("accuracy", TEST_ACCURACY)
                putDouble("bearing", TEST_BEARING)
            }
            intent.putExtras(bundle)
            
            context.sendBroadcast(intent)
            Log.d(TAG, "测试导航数据广播已发送")
        } catch (e: Exception) {
            Log.e(TAG, "发送测试导航数据失败: ${e.message}", e)
        }
    }

    /**
     * 发送模拟的位置数据广播
     */
    fun sendTestLocationData() {
        try {
            val intent = Intent(AmapAutoReceiver.AMAPAUTO_LOCATION_ACTION)
            val bundle = Bundle().apply {
                putString("action", "location")
                putLong("timestamp", System.currentTimeMillis())
                putDouble("latitude", TEST_LATITUDE)
                putDouble("longitude", TEST_LONGITUDE)
                putDouble("speed", TEST_SPEED)
                putDouble("bearing", TEST_BEARING)
                putDouble("accuracy", TEST_ACCURACY)
                putString("provider", "gps")
            }
            intent.putExtras(bundle)
            
            context.sendBroadcast(intent)
            Log.d(TAG, "测试位置数据广播已发送")
        } catch (e: Exception) {
            Log.e(TAG, "发送测试位置数据失败: ${e.message}", e)
        }
    }

    /**
     * 发送模拟的标准广播
     */
    fun sendTestStandardBroadcast() {
        try {
            val intent = Intent(AmapAutoReceiver.AUTONAVI_STANDARD_BROADCAST)
            val bundle = Bundle().apply {
                putString("action", "standard_broadcast")
                putLong("timestamp", System.currentTimeMillis())
                putString("version", "1.0.0")
                putString("type", "navigation")
                putString("status", "active")
                putInt("progress", 50)
                putString("destination", "天安门广场")
            }
            intent.putExtras(bundle)
            
            context.sendBroadcast(intent)
            Log.d(TAG, "测试标准广播已发送")
        } catch (e: Exception) {
            Log.e(TAG, "发送测试标准广播失败: ${e.message}", e)
        }
    }

    /**
     * 发送自定义测试数据
     */
    fun sendCustomTestData(action: String, data: Map<String, Any>) {
        try {
            val intent = Intent(action)
            val bundle = Bundle()
            
            data.forEach { (key, value) ->
                when (value) {
                    is String -> bundle.putString(key, value)
                    is Int -> bundle.putInt(key, value)
                    is Long -> bundle.putLong(key, value)
                    is Double -> bundle.putDouble(key, value)
                    is Float -> bundle.putFloat(key, value)
                    is Boolean -> bundle.putBoolean(key, value)
                    else -> bundle.putString(key, value.toString())
                }
            }
            
            intent.putExtras(bundle)
            context.sendBroadcast(intent)
            Log.d(TAG, "自定义测试数据已发送: action=$action, data=$data")
        } catch (e: Exception) {
            Log.e(TAG, "发送自定义测试数据失败: ${e.message}", e)
        }
    }

    /**
     * 发送错误数据测试异常处理
     */
    fun sendErrorTestData() {
        try {
            val intent = Intent("INVALID_ACTION_FOR_TEST")
            // 不添加任何数据，测试空数据处理
            
            context.sendBroadcast(intent)
            Log.d(TAG, "错误测试数据已发送")
        } catch (e: Exception) {
            Log.e(TAG, "发送错误测试数据失败: ${e.message}", e)
        }
    }

    /**
     * 批量发送测试数据
     */
    fun sendBatchTestData() {
        Log.d(TAG, "开始批量发送测试数据")
        
        // 发送位置数据
        sendTestLocationData()
        
        // 延迟发送导航数据
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            sendTestNavigationData()
        }, 1000)
        
        // 延迟发送标准广播
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            sendTestStandardBroadcast()
        }, 2000)
        
        Log.d(TAG, "批量测试数据发送完成")
    }
}