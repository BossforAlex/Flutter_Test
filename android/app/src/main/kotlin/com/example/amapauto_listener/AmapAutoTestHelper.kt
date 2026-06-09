package com.example.amapauto_listener

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * 高德地图广播测试助手类
 * 用于模拟高德地图广播数据，便于调试和测试
 * 遵循 AmapAuto 标准广播协议字段命名
 */
class AmapAutoTestHelper(private val context: Context) {
    companion object {
        private const val TAG = "AmapAutoTestHelper"

        const val ACTION_SEND = "AUTONAVI_STANDARD_BROADCAST_SEND"
        const val ACTION_RECV = "AUTONAVI_STANDARD_BROADCAST_RECV"

        // 测试数据常量
        const val TEST_LATITUDE = 39.9042
        const val TEST_LONGITUDE = 116.4074
        const val TEST_SPEED = 60
        const val TEST_LIMIT = 80
        const val TEST_BEARING = 90
        const val TEST_REMAIN_DIS = 1500
        const val TEST_REMAIN_TIME = 300
        const val TEST_CUR_ROAD = "长安街"
        const val TEST_NEXT_ROAD = "建国路"
        const val TEST_ICON = 2 // 左转
    }

    /**
     * 发送模拟的导航引导信息广播 (KEY_TYPE = 10001)
     */
    fun sendTestNavigationGuidance() {
        try {
            val intent = Intent(ACTION_SEND)
            intent.addCategory("AUTONAVI_STANDARD_CATEGORY")
            intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)

            val bundle = Bundle().apply {
                putInt("KEY_TYPE", 10001)
                putString("KEY_ACTION", "turn-left")
                putString("CUR_ROAD_NAME", TEST_CUR_ROAD)
                putString("NEXT_ROAD_NAME", TEST_NEXT_ROAD)
                putInt("ROUTE_REMAIN_DIS", TEST_REMAIN_DIS)
                putInt("ROUTE_REMAIN_TIME", TEST_REMAIN_TIME)
                putInt("CUR_SPEED", TEST_SPEED)
                putInt("LIMITED_SPEED", TEST_LIMIT)
                putInt("ICON", TEST_ICON)
                putDouble("CAR_LATITUDE", TEST_LATITUDE)
                putDouble("CAR_LONGITUDE", TEST_LONGITUDE)
                putInt("CAR_DIRECTION", TEST_BEARING)
                putInt("SEG_REMAIN_DIS", 500)
                putInt("SEG_REMAIN_TIME", 100)
                putInt("ROAD_TYPE", 2) // 国道
                putInt("TRAFFIC_LIGHT_NUM", 3)
            }
            intent.putExtras(bundle)
            context.sendBroadcast(intent)
            Log.d(TAG, "测试导航引导信息广播已发送 (KEY_TYPE=10001)")
        } catch (e: Exception) {
            Log.e(TAG, "发送测试导航数据失败: ${e.message}", e)
        }
    }

    /**
     * 发送模拟的导航状态广播 (KEY_TYPE = 10019)
     */
    fun sendTestNavigationState(state: Int = 10) {
        try {
            val intent = Intent(ACTION_SEND)
            intent.addCategory("AUTONAVI_STANDARD_CATEGORY")
            intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)

            val bundle = Bundle().apply {
                putInt("KEY_TYPE", 10019)
                putInt("EXTRA_STATE", state)
            }
            intent.putExtras(bundle)
            context.sendBroadcast(intent)
            Log.d(TAG, "测试导航状态广播已发送 (EXTRA_STATE=$state)")
        } catch (e: Exception) {
            Log.e(TAG, "发送导航状态失败: ${e.message}", e)
        }
    }

    /**
     * 发送模拟的摄像头信息广播
     */
    fun sendTestCameraInfo(cameraType: Int = 1, cameraDist: Int = 300, cameraSpeed: Int = 60) {
        try {
            val intent = Intent(ACTION_SEND)
            intent.addCategory("AUTONAVI_STANDARD_CATEGORY")
            intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)

            val bundle = Bundle().apply {
                putInt("KEY_TYPE", 10001)
                putInt("CAMERA_DIST", cameraDist)
                putInt("CAMERA_TYPE", cameraType)
                putInt("CAMERA_SPEED", cameraSpeed)
            }
            intent.putExtras(bundle)
            context.sendBroadcast(intent)
            Log.d(TAG, "测试摄像头信息广播已发送")
        } catch (e: Exception) {
            Log.e(TAG, "发送摄像头信息失败: ${e.message}", e)
        }
    }

    /**
     * 批量发送多种测试数据
     */
    fun sendBatchTestData() {
        Log.d(TAG, "开始批量发送测试数据")
        sendTestNavigationState(10) // 路径规划完成
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            sendTestNavigationGuidance()
        }, 500)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            sendTestCameraInfo()
        }, 1000)
        Log.d(TAG, "批量测试数据发送完成")
    }
}