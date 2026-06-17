package com.tuningvibes.tuning_vibes

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val AUDIO_CHANNEL = "com.tuningvibes/audio"
    private val CONTROL_CHANNEL = "com.tuningvibes/control"
    
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 22050
                    val success = startRecording(sampleRate)
                    result.success(success)
                }
                "stop" -> {
                    stopRecording()
                    result.success(true)
                }
                "hasPermission" -> {
                    val hasPermission = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPermission)
                }
                "requestPermission" -> {
                    requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1001)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startRecording(sampleRate: Int): Boolean {
        if (isRecording) return true
        val bufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            return false
        }
        
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return false
        }
        
        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
        } catch (e: SecurityException) {
            return false
        }
        
        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            return false
        }
        
        audioRecord?.startRecording()
        isRecording = true
        
        recordingThread = thread(start = true) {
            val buffer = ShortArray(1024)
            while (isRecording) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                if (read > 0) {
                    val doubleArray = DoubleArray(read)
                    for (i in 0 until read) {
                        doubleArray[i] = buffer[i].toDouble() / 32768.0
                    }
                    runOnUiThread {
                        eventSink?.success(doubleArray)
                    }
                }
            }
        }
        return true
    }
    
    private fun stopRecording() {
        isRecording = false
        recordingThread?.join()
        recordingThread = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }
}
