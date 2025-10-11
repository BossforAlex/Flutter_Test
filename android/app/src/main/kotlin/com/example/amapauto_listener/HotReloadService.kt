package com.example.amapauto_listener

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.Timer
import java.util.TimerTask

/**
 * 热重载服务 - 负责监控文件变更并触发重载
 */
class HotReloadService : Service() {
    
    companion object {
        const val TAG = "HotReloadService"
        const val ACTION_START_MONITORING = "com.example.amapauto_listener.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.example.amapauto_listener.STOP_MONITORING"
        const val ACTION_TRIGGER_RELOAD = "com.example.amapauto_listener.TRIGGER_RELOAD"
    }
    
    private var isMonitoring = false
    private var timer: Timer? = null
    private val fileTimestamps = mutableMapOf<String, Long>()
    private val changedFiles = mutableSetOf<String>()
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_MONITORING -> {
                startMonitoring()
                Log.i(TAG, "开始监控文件变更")
            }
            ACTION_STOP_MONITORING -> {
                stopMonitoring()
                Log.i(TAG, "停止监控文件变更")
            }
            ACTION_TRIGGER_RELOAD -> {
                triggerReload()
                Log.i(TAG, "手动触发热重载")
            }
        }
        return START_STICKY
    }
    
    /**
     * 开始监控文件变更
     */
    private fun startMonitoring() {
        if (isMonitoring) return
        
        isMonitoring = true
        timer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    checkForChanges()
                }
            }, 0, 1000) // 每秒检查一次
        }
        
        // 初始化文件时间戳
        initializeFileTimestamps()
    }
    
    /**
     * 停止监控
     */
    private fun stopMonitoring() {
        isMonitoring = false
        timer?.cancel()
        timer = null
        fileTimestamps.clear()
        changedFiles.clear()
    }
    
    /**
     * 初始化文件时间戳
     */
    private fun initializeFileTimestamps() {
        try {
            val libDir = File(filesDir, "../lib")
            if (libDir.exists() && libDir.isDirectory) {
                libDir.walk()
                    .filter { it.isFile && it.extension == "dart" }
                    .forEach { file ->
                        fileTimestamps[file.absolutePath] = file.lastModified()
                    }
            }
        } catch (e: Exception) {
            Log.e(TAG, "初始化文件时间戳失败", e)
        }
    }
    
    /**
     * 检查文件变更
     */
    private fun checkForChanges() {
        try {
            val libDir = File(filesDir, "../lib")
            if (!libDir.exists() || !libDir.isDirectory) return
            
            var hasChanges = false
            
            libDir.walk()
                .filter { it.isFile && it.extension == "dart" }
                .forEach { file ->
                    val path = file.absolutePath
                    val lastModified = file.lastModified()
                    
                    if (fileTimestamps.containsKey(path)) {
                        if (lastModified != fileTimestamps[path]) {
                            changedFiles.add(path)
                            fileTimestamps[path] = lastModified
                            hasChanges = true
                            Log.d(TAG, "检测到文件变更: ${file.name}")
                        }
                    } else {
                        fileTimestamps[path] = lastModified
                    }
                }
            
            if (hasChanges && changedFiles.size > 0) {
                Log.i(TAG, "检测到 ${changedFiles.size} 个文件变更，触发热重载")
                triggerReload()
            }
        } catch (e: Exception) {
            Log.e(TAG, "检查文件变更失败", e)
        }
    }
    
    /**
     * 触发热重载
     */
    private fun triggerReload() {
        try {
            // 发送广播通知Flutter应用
            val reloadIntent = Intent("com.example.amapauto_listener.HOT_RELOAD_TRIGGERED")
            reloadIntent.putExtra("changed_files", changedFiles.toTypedArray())
            sendBroadcast(reloadIntent)
            
            Log.i(TAG, "热重载触发，变更文件: ${changedFiles.size}")
            
            // 清空变更文件列表
            changedFiles.clear()
        } catch (e: Exception) {
            Log.e(TAG, "触发热重载失败", e)
        }
    }
    
    /**
     * 手动触发热重载
     */
    fun triggerManualReload() {
        changedFiles.addAll(fileTimestamps.keys)
        triggerReload()
    }
    
    /**
     * 获取服务状态
     */
    fun getServiceStatus(): Map<String, Any> {
        return mapOf(
            "isMonitoring" to isMonitoring,
            "monitoredFiles" to fileTimestamps.size,
            "changedFiles" to changedFiles.size,
            "lastCheck" to System.currentTimeMillis()
        )
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopMonitoring()
        Log.i(TAG, "热重载服务已销毁")
    }
}