package com.example.amapauto_listener

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var receiver: AmapAutoReceiver? = null
    private lateinit var channel: MethodChannel
    private val CHANNEL = "com.example.amapauto_listener/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        channel.setMethodCallHandler { call, result -> 
            when (call.method) {
                "startListening" -> {
                    // 确保只创建一个接收器实例
                    if (receiver == null) {
                        receiver = AmapAutoReceiver(this, channel)
                        receiver?.register()
                        result.success("监听器已启动")
                    } else {
                        result.error("ALREADY_LISTENING", "监听器已经在运行", null)
                    }
                }
                "stopListening" -> {
                    receiver?.unregister()
                    receiver = null
                    result.success("监听器已停止")
                }
                "getLastNavigationData" -> {
                    val data = receiver?.getLastNavigationData()
                    if (data != null) {
                        result.success(data)
                    } else {
                        result.error("NO_DATA", "没有导航数据", null)
                    }
                }
                "getListeningActions" -> {
                    val actions = receiver?.getListeningActions() ?: emptyList()
                    result.success(actions)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}