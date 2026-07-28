/*
 * EchoModule.kt
 *
 * 短音效播放模块（跨端）。
 *
 * 设计目标：按 Kuikly Module 机制提供轻量级短音效播放 API，与 KuiklyAudio（长音频播放）完全解耦。
 * 使用 SoundPool（Android）/ AVAudioPlayer（iOS）/ 轻量播放器（鸿蒙）作为底层引擎，
 * 支持并发播放多个音效，延迟 < 50ms。
 *
 * 能力面：
 *  - 播放音效（从 assets/sounds 目录加载）
 *  - 停止所有播放
 *  - 预加载音效到内存
 *  - 释放所有资源
 *
 * 约定：
 *  - MODULE_NAME 必须等于各端原生注册名 / 类名（iOS 类名须精确等于 moduleName）。
 *  - 参数统一以 JSONObject 序列化字符串透传，原生侧按同名 JSON key 解析。
 *  - commonMain 禁止书写平台相关代码。
 *
 * 本文件属于独立发布库 KuiklyEcho（groupId=com.jlj.kuiklybase）。
 */

package com.jlj.kuiklybase.echo

import com.tencent.kuikly.core.module.Module
import com.tencent.kuikly.core.nvi.serialization.json.JSONObject

/**
 * 短音效播放模块。
 *
 * 通过 [moduleName] 与原生侧同名 Module 桥接（Android [KREchoModule]、
 * iOS [KREchoModule]、鸿蒙 [KREchoModule]）。
 */
public class EchoModule : Module() {

    override fun moduleName(): String = MODULE_NAME

    /**
     * 播放音效。
     *
     * @param soundName 音效文件名（含扩展名），如 "click.wav"、"success.mp3"。
     *  原生侧从 assets/sounds/（Android）或 Bundle resources（iOS）或 rawfile（鸿蒙）加载。
     * @param volume 音量 0.0~1.0（默认 1.0）。
     */
    fun play(soundName: String, volume: Float = 1f) {
        val params = JSONObject().apply {
            put(KEY_SOUND_NAME, soundName)
            put(KEY_VOLUME, volume)
        }
        toNative(false, METHOD_PLAY, params.toString(), null, false)
    }

    /**
     * 停止当前所有正在播放的音效。
     */
    fun stop() {
        toNative(false, METHOD_STOP, null, null, false)
    }

    /**
     * 预加载音效到内存，后续 [play] 调用可实现零延迟播放。
     *
     * @param soundName 音效文件名（含扩展名）。
     */
    fun preload(soundName: String) {
        val params = JSONObject().apply {
            put(KEY_SOUND_NAME, soundName)
        }
        toNative(false, METHOD_PRELOAD, params.toString(), null, false)
    }

    /**
     * 释放所有音效资源（SoundPool / AVAudioPlayer 等）。
     * 调用后需重新 [preload] 或 [play] 才能继续使用。
     */
    fun release() {
        toNative(false, METHOD_RELEASE, null, null, false)
    }

    companion object {
        const val MODULE_NAME = "KREchoModule"
        const val METHOD_PLAY = "play"
        const val METHOD_STOP = "stop"
        const val METHOD_PRELOAD = "preload"
        const val METHOD_RELEASE = "release"

        const val KEY_SOUND_NAME = "soundName"
        const val KEY_VOLUME = "volume"
    }
}
