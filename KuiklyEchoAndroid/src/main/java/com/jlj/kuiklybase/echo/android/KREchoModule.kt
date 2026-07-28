/*
 * KREchoModule.kt
 *
 * 安卓侧短音效播放模块（Kuikly 原生 Module 实现）。
 *
 * 与 commonMain 的 EchoModule（moduleName = "KREchoModule"）桥接，
 * 在 KuiklyRenderActivity 的 registerExternalModule 中以同名注册。
 *
 * 能力映射（基于 android.media.SoundPool）：
 *  - play     -> SoundPool.play(soundId, leftVolume, rightVolume, priority, loop, rate)
 *  - stop     -> SoundPool.autoPause()（暂停所有流）
 *  - preload  -> SoundPool.load(AssetFileDescriptor)（预加载到内存）
 *  - release  -> SoundPool.release()（释放资源）
 *
 * 说明：
 *  - SoundPool 支持最多 maxStreams 个并发音效流（默认 8）。
 *  - 音效文件从 assets/sounds/ 目录加载。
 *  - 内部维护 soundIdMap 缓存，避免重复加载同一音效。
 *
 * 本文件属于独立发布库 KuiklyEchoAndroid（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.echo.android

import android.media.AudioAttributes
import android.media.SoundPool
import com.tencent.kuikly.core.render.android.export.KuiklyRenderBaseModule
import com.tencent.kuikly.core.render.android.export.KuiklyRenderCallback
import org.json.JSONObject

public class KREchoModule : KuiklyRenderBaseModule() {

    private var soundPool: SoundPool? = null
    private val soundIdMap = mutableMapOf<String, Int>()
    private val activeStreamIds = mutableSetOf<Int>()

    override fun call(method: String, params: String?, callback: KuiklyRenderCallback?): Any? {
        return try {
            when (method) {
                METHOD_PLAY -> {
                    handlePlay(params)
                    null
                }
                METHOD_STOP -> {
                    handleStop()
                    null
                }
                METHOD_PRELOAD -> {
                    handlePreload(params)
                    null
                }
                METHOD_RELEASE -> {
                    handleRelease()
                    null
                }
                else -> {
                    callback?.invoke(mapOf("code" to -1, "message" to "method not found: $method"))
                    null
                }
            }
        } catch (e: Exception) {
            callback?.invoke(mapOf("code" to -2, "message" to (e.message ?: "unknown error")))
            null
        }
    }

    private fun getOrCreateSoundPool(): SoundPool {
        soundPool?.let { return it }
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder()
            .setMaxStreams(MAX_STREAMS)
            .setAudioAttributes(attrs)
            .build()
        pool.setOnLoadCompleteListener { _, _, _ -> }
        soundPool = pool
        return pool
    }

    private fun loadSound(soundName: String): Int {
        soundIdMap[soundName]?.let { return it }
        val ctx = context ?: return -1
        val afd = ctx.assets.openFd("sounds/$soundName")
        try {
            val soundId = getOrCreateSoundPool().load(afd, 1)
            soundIdMap[soundName] = soundId
            return soundId
        } finally {
            afd.close()
        }
    }

    private fun handlePlay(params: String?) {
        val json = JSONObject(params ?: "{}")
        val soundName = json.optString(KEY_SOUND_NAME, "")
        val volume = json.optDouble(KEY_VOLUME, 1.0).toFloat().coerceIn(0f, 1f)
        if (soundName.isEmpty()) return
        val soundId = loadSound(soundName)
        if (soundId == -1) return
        val pool = getOrCreateSoundPool()
        val streamId = pool.play(soundId, volume, volume, 0, 0, 1f)
        if (streamId != 0) {
            synchronized(activeStreamIds) {
                activeStreamIds.add(streamId)
            }
        }
    }

    private fun handleStop() {
        val pool = soundPool ?: return
        synchronized(activeStreamIds) {
            for (streamId in activeStreamIds) {
                pool.stop(streamId)
            }
            activeStreamIds.clear()
        }
    }

    private fun handlePreload(params: String?) {
        val json = JSONObject(params ?: "{}")
        val soundName = json.optString(KEY_SOUND_NAME, "")
        if (soundName.isEmpty()) return
        loadSound(soundName)
    }

    private fun handleRelease() {
        soundPool?.release()
        soundPool = null
        soundIdMap.clear()
        synchronized(activeStreamIds) {
            activeStreamIds.clear()
        }
    }

    companion object {
        const val MODULE_NAME = "KREchoModule"
        const val METHOD_PLAY = "play"
        const val METHOD_STOP = "stop"
        const val METHOD_PRELOAD = "preload"
        const val METHOD_RELEASE = "release"
        const val KEY_SOUND_NAME = "soundName"
        const val KEY_VOLUME = "volume"
        const val MAX_STREAMS = 8
    }
}
