# BlankOS - 零抽成插件化容器应用

## 项目简介

BlankOS 是一个**完全空白的插件化容器 App**。App 本身不提供任何功能，所有能力由用户/社区以"插件包"形式提供。

**核心差异：零抽成**，开发者创造的插件卖出的每一分钱都 100% 归开发者，App 不抽取任何佣金。

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── core/
│   └── plugin_manager.dart      # 插件管理器（单例）
├── models/
│   └── plugin_manifest.dart     # 插件清单数据模型
└── ui/
    ├── home_page.dart           # 主页面
    └── plugin_sandbox.dart      # 插件沙箱 WebView 页面
```

## 依赖项

- `webview_flutter` - 插件 WebView 沙箱
- `path_provider` - 管理插件目录
- `archive` - 解压 ZIP 插件包
- `shared_preferences` - 存储最近使用的插件列表
- `file_picker` - 文件选择器

## 运行说明

### 前置条件

1. 安装 Flutter SDK（3.4.0 或更高版本）
2. 配置 Flutter 环境变量
3. 安装 Android Studio / Xcode（根据目标平台）

### 安装依赖

```bash
cd blankos
flutter pub get
```

### 运行应用

```bash
# Android
flutter run

# iOS (macOS only)
cd ios && pod install && cd ..
flutter run
```

### 构建发布版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
```

## 权限配置

### Android (AndroidManifest.xml)

已配置以下权限：
- `INTERNET` - 网络访问
- `READ_EXTERNAL_STORAGE` - 读取外部存储
- `WRITE_EXTERNAL_STORAGE` - 写入外部存储
- `MANAGE_EXTERNAL_STORAGE` - 管理外部存储（Android 11+）
- `VIBRATE` - 震动

### iOS (Info.plist)

已配置：
- `NSAppTransportSecurity` - 允许 HTTP 请求

## 插件开发指南

### 插件包格式

插件为 ZIP 压缩包，包含：

1. `manifest.json` - 插件清单（必需）
2. 入口 HTML 文件（如 `index.html`）

### manifest.json 格式

```json
{
  "id": "com.example.plugin",
  "name": "插件名称",
  "version": "1.0.0",
  "entry": "index.html",
  "permissions": [],
  "author": "开发者名称",
  "price": 0,
  "payment_address": "可选的支付地址"
}
```

### Bridge API

插件可通过 `window.Bridge` 与原生交互：

```javascript
// 复制到剪贴板
window.Bridge.postMessage(JSON.stringify({
    action: 'copyToClipboard',
    params: { text: '要复制的文本' }
}));

// 震动
window.Bridge.postMessage(JSON.stringify({
    action: 'vibrate',
    params: { duration: 100 }
}));

// 获取剪贴板内容
window.Bridge.postMessage(JSON.stringify({
    action: 'getClipboardText'
}));
```

## 测试插件

### 方法一：使用示例插件

1. 运行 `pack_plugin.bat`（Windows）或 `pack_plugin.sh`（macOS/Linux）打包示例插件
2. 将生成的 `hello_world.zip` 复制到手机
3. 在 BlankOS 中点击右下角浮动按钮或长按屏幕导入

### 方法二：手动创建

1. 创建文件夹 `hello_world`
2. 在其中创建 `manifest.json` 和 `index.html`
3. 将文件夹压缩为 `hello_world.zip`
4. 通过 App 导入

### 方法三：ADB 推送（Android 开发者）

```bash
# 获取应用文档目录路径
adb shell run-as com.blankos.blankos ls files

# 推送插件（需要 root 或调试版本）
adb push hello_world.zip /sdcard/Download/
# 然后在 App 中导入

# 或者直接解压到插件目录
adb shell mkdir -p /sdcard/Android/data/com.blankos.blankos/files/plugins/hello.world/
adb push manifest.json /sdcard/Android/data/com.blankos.blankos/files/plugins/hello.world/
adb push index.html /sdcard/Android/data/com.blankos.blankos/files/plugins/hello.world/
```

## 功能特性

- ✅ 插件扫描与列表展示
- ✅ ZIP 插件包导入安装
- ✅ 插件卸载
- ✅ WebView 沙箱运行
- ✅ Bridge API（剪贴板、震动）
- ✅ 最近使用记录
- ✅ 空状态"零抽成"宣言

## 许可证

MIT License
