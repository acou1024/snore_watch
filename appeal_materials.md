# App Store 4.3(a) 申诉材料

## 申诉信（英文）

```
Dear App Review Team,

I am writing to appeal the rejection of my app "鼾声守望者" (Snore Watch) under Guideline 4.3(a).

I want to clarify that this app was independently developed from scratch by myself, not using any template, repackaged code, or third-party app generator. Here is the evidence:

## 1. Original Development Evidence

**Git Commit History (46 commits over 4 days):**

| Date | Commits | Description |
|------|---------|-------------|
| 2026-02-07 | Initial commit | Created Flutter project from scratch |
| 2026-02-08 | 6 commits | iOS configuration, Bundle ID setup, crash fixes |
| 2026-02-09 | 28 commits | Core features: audio recording, permissions, UI optimization |
| 2026-02-10 | 11 commits | App Store preparation, icon updates, bug fixes |

This commit history clearly shows the progressive development process, not a template-based approach.

## 2. Unique Features

Our app has several distinctive features:

1. **Real-time Snoring Detection** - Custom audio analysis algorithm with 5 adjustable sensitivity levels
2. **Multiple Alert Methods** - Vibration, sound alerts, and flashlight options
3. **Smart Recording Mode** - Records only when snoring is detected, saving storage
4. **Background Monitoring** - Works overnight with screen off
5. **Native iOS Integration** - Custom Swift code for audio session management and notifications
6. **Fully Chinese Localized** - Designed specifically for Chinese users

## 3. Technical Implementation

- **Framework**: Flutter with custom Dart code
- **Audio Processing**: Custom implementation using flutter_sound package
- **iOS Native Code**: Original Swift code in AppDelegate.swift for:
  - Audio session management (recording/playback switching)
  - Native notification handling
  - Background task support
- **UI Design**: Original design with custom icons and animations

## 4. Code Samples

I have attached screenshots of my original source code:
- Main detection algorithm (snore_watch.dart)
- iOS native integration (AppDelegate.swift)
- Custom UI components

## 5. Development Timeline

- Feb 7: Project initialization
- Feb 8: iOS platform setup and crash fixes
- Feb 9: Core functionality implementation (audio, permissions, UI)
- Feb 10: App Store submission preparation

I can provide full source code access, additional screenshots, or any other evidence you may need. This is 100% original work developed by me.

Please reconsider my submission.

Thank you for your time and consideration.

Best regards,
宋世柯 (Song Shike)
```

---

## Git 提交历史（完整）

```
f5ba40e 2026-02-10 Remove deprecated UIApplicationExitsOnSuspend key
3d1db6b 2026-02-10 Simplify iOS signing config for App Store build
55ac65b 2026-02-10 Add strict-match-identifier for profile fetching
6ff81ed 2026-02-10 Remove --create flag for profile fetching
9fb7927 2026-02-10 Fix App Store Connect integration name
b9eaedd 2026-02-10 Configure Codemagic for App Store upload
7879909 2026-02-10 Add beautiful splash screen with custom image
4f1eee7 2026-02-10 Fix isOpen method not found - use openRecorder directly
03d3ac7 2026-02-10 Fix recording failure after mode switch
7c009a0 2026-02-10 Update app icon to new version without white border
f4c4453 2026-02-10 Fix iOS notification badge issue
47a41e1 2026-02-09 Add app icon, splash screen, privacy policy and support pages
1a60a57 2026-02-09 优化睡眠提醒弹窗UI
ffccfff 2026-02-09 删除4个wav测试铃声
ed6cfe2 2026-02-09 修复录音计数问题
8ca1ace 2026-02-09 彻底修复录音保存问题
c6478c3 2026-02-09 修复切换模式后录音状态未重置的问题
2239fa8 2026-02-09 改进录音保存逻辑
4e75dee 2026-02-09 修复仅录音模式下录音文件未保存的问题
6281cb2 2026-02-09 修复iOS铃声播放
c001496 2026-02-09 iOS使用原生AVAudioPlayer播放音频
817217b 2026-02-09 添加iOS后台任务支持
dd87390 2026-02-09 修复iOS息屏播放
3212044 2026-02-09 添加用户设置持久化
99eaf45 2026-02-09 修复iOS音频会话切换
e8897d5 2026-02-09 修复iOS音频中断问题
324a46f 2026-02-09 增强iOS扬声器播放
6f21aad 2026-02-09 修复iOS音量问题
3f70e66 2026-02-09 修复iOS音量：使用mediaPlayer模式
c55bfa3 2026-02-09 修复iOS叫醒音量太小
b85b01c 2026-02-09 file_picker改用custom类型
8d7b1ab 2026-02-09 iOS跳过Flutter权限检查
2f32fa1 2026-02-09 iOS原生方式申请麦克风和通知权限
2c0ea8a 2026-02-09 启动时申请所有权限
ecb8abe 2026-02-09 添加iOS媒体库和相册权限配置
29138a4 2026-02-09 修复iOS权限申请
0444fdd 2026-02-09 添加iOS原生功能
232f851 2026-02-08 添加iOS Podfile配置
669224c 2026-02-08 简化AppDelegate到最基本版本测试闪退
1cadad7 2026-02-08 修复iOS闪退：添加通知初始化错误处理
624be53 2026-02-08 修复iOS启动闪退：延迟初始化避免崩溃
a03250d 2026-02-08 修复 AppDelegate.swift 编译错误
fa6df52 2026-02-08 修改 iOS Bundle ID
8ce2601 2026-02-07 Initial commit - SnoreWatch Flutter app with iOS support
```

---

## 提交申诉步骤

1. 登录 App Store Connect
2. 找到被拒绝的应用版本
3. 点击 "Reply" 或进入 Resolution Center
4. 复制上面的英文申诉信内容
5. 附加以下截图：
   - Git提交历史截图
   - 核心代码截图（snore_watch.dart）
   - iOS原生代码截图（AppDelegate.swift）
6. 提交申诉
