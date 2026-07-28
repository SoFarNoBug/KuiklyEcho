# KuiklyEcho

Kuikly 跨端短音效播放模块，与 KuiklyAudio（长音频播放）完全解耦。

使用轻量级引擎（Android SoundPool / iOS AVAudioPlayer / 鸿蒙 SoundPool）播放短音效，支持并发播放多个音效，延迟 < 50ms。

## 特性

- **并发播放** — 支持同时播放多个音效，互不干扰
- **低延迟** — SoundPool/AVAudioPlayer 引擎，播放响应 < 50ms
- **预加载** — 支持提前加载音效到内存，实现零延迟播放
- **跨端统一** — Android / iOS / 鸿蒙 三端 API 完全一致
- **轻量** — 无重型依赖，仅依赖 Kuikly Core

## 平台引擎

| 平台 | 引擎 | 最大并发 | 最低版本 |
|------|------|---------|---------|
| Android | SoundPool | 8 路 | API 21 |
| iOS | AVAudioPlayer | 无限制 | iOS 11.0 |
| 鸿蒙 | media.SoundPool | 无限制 | API 12 |

## 依赖声明

### 1. settings.gradle.kts

```kotlin
maven {
    url = uri("https://maven.pkg.github.com/SoFarNoBug/KuiklyEcho")
}
```

### 2. shared/build.gradle.kts（KMP 公共层）

```kotlin
implementation("com.jlj.kuiklybase:kuiklyecho:0.0.1-2.1.21")
```

### 3. androidApp/build.gradle.kts（Android 原生层）

```kotlin
implementation("com.jlj.kuiklybase:kuiklyechoandroid:0.0.1-2.1.21")
```

## 集成步骤

### 1. 注册 Module

在 `BasePager.kt` 的 `createExternalModules()` 中注册：

```kotlin
import com.jlj.kuiklybase.echo.EchoModule

override fun createExternalModules(): Map<String, Module>? {
    val externalModules = hashMapOf<String, Module>()
    externalModules[EchoModule.MODULE_NAME] = EchoModule()
    return externalModules
}
```

### 2. 注入 CompositionLocal

在 `HomePager.kt` 的 `created()` 中获取并注入：

```kotlin
import com.jlj.kuiklybase.echo.LocalEchoModule
import com.jlj.kuiklybase.echo.EchoModule

override fun created() {
    super.created()
    val echoModule = acquireModule<EchoModule>(EchoModule.MODULE_NAME)

    setContent {
        CompositionLocalProvider(
            LocalEchoModule provides echoModule
        ) {
            // ... NavHost ...
        }
    }
}
```

### 3. 在页面中使用

```kotlin
import com.jlj.kuiklybase.echo.LocalEchoModule

@Composable
fun MyScreen() {
    val echo = LocalEchoModule.current

    Button(onClick = { echo.play("click.wav") }) {
        Text("播放音效")
    }
}
```

## API 参考

### `EchoModule`

| 方法 | 参数 | 说明 |
|------|------|------|
| `play(soundName, volume)` | `soundName`: 音效文件名（含扩展名）<br>`volume`: 音量 0.0~1.0（默认 1.0） | 播放音效 |
| `stop()` | 无 | 停止所有正在播放的音效 |
| `preload(soundName)` | `soundName`: 音效文件名 | 预加载音效到内存，后续 play 零延迟 |
| `release()` | 无 | 释放所有资源，需重新 preload/play 才能继续使用 |

### `LocalEchoModule`

Compose CompositionLocal，提供 `EchoModule` 实例给子树。通过 `LocalEchoModule.current` 获取。

## 音效资源目录

将音效文件放入各平台 App 的对应目录：

| 平台 | 目录 |
|------|------|
| Android | `androidApp/src/main/assets/sounds/` |
| iOS | App Bundle 的 `sounds/` 子目录（添加到 Xcode bundle resources） |
| 鸿蒙 | `ohosApp/src/main/resources/rawfile/sounds/` |

## 支持的音频格式

| 格式 | Android | iOS | 鸿蒙 | 推荐 |
|------|---------|-----|------|------|
| WAV | ✅ | ✅ | ✅ | 无损、加载快，推荐 |
| MP3 | ✅ | ✅ | ✅ | 体积小，兼容性好 |
| AAC | ✅ | ✅ | ✅ | — |
| OGG | ✅ | ❌ | ✅ | iOS 不支持，不推荐跨端使用 |

## 项目结构

```
KuiklyEcho/                 # KMP 公共层（EchoModule + LocalEchoModule）
KuiklyEchoAndroid/          # Android 原生层（SoundPool）
KuiklyEchoIOS/              # iOS 原生层（AVAudioPlayer）
KuiklyEchoOhos/             # 鸿蒙原生层（SoundPool）
```

## 发布

```bash
# 发布 Maven（KMP + Android）
./publish-maven.sh

# iOS CocoaPods
cd KuiklyEchoIOS && pod trunk push KuiklyEcho.podspec

# 鸿蒙 ohpm
cd KuiklyEchoOhos && ohpm publish
```
