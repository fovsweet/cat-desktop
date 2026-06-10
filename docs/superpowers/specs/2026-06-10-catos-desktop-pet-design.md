# CatOS — 桌面宠物应用设计文档

日期:2026-06-10
状态:自主模式下确定(后台任务,关键假设已在会话中列出,可随时修订)

## 目标

一个 macOS 桌面应用:用户上传一张宠物照片(猫/狗),应用本地抠图并生成
多姿态动画,然后在桌面上生成一只跟随鼠标视线、可点击互动、可右键投喂/
抚摸的桌宠。

## 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 技术栈 | Swift + AppKit/SwiftUI,SwiftPM | 原生透明窗口/置顶/低占用;无需 Electron |
| 抠图 | Vision `VNGenerateForegroundInstanceMaskRequest` | 本地、免费、无需 API key,宠物主体效果好 |
| 多角度动作 | 2.5D 程序化木偶(变换 + 眼睛叠加层) | 零依赖零成本;云端 AI 重绘留扩展接口 |
| 眼睛定位 | Vision `VNDetectAnimalBodyPoseRequest`(猫狗),失败则手动标记 | 自动为主,手动兜底 |
| 鼠标跟踪 | 定时轮询 `NSEvent.mouseLocation` | 不需要辅助功能权限 |

## 架构

```
CatOS (SwiftPM executable, macOS 14+)
├── App        AppDelegate、状态栏菜单、生命周期
├── Model      PetProfile (Codable)、PetStore (Application Support 持久化)
├── Processing CutoutProcessor (Vision 抠图)、PoseAnalyzer (眼睛/头部检测)
├── Onboarding 导入窗口:拖拽照片 → 抠图预览 → 眼睛标记/确认 → 上桌面
└── Pet        PetWindowController (透明 NSPanel)
               PetView (CALayer 木偶:身体/眼睛/爪子/食物/爱心)
               BehaviorEngine (状态机)、MouseTracker
```

## 行为状态机

```
idle ──鼠标移动──▶ watching(瞳孔+身体朝向跟随)
idle/watching ──左键点宠物──▶ pawing(伸爪拍向光标)──▶ watching
watching ──快速连点──▶ pouncing(整窗跳向光标捕捉)──▶ idle
任意 ──右键菜单·投喂──▶ eating(食物下落、低头进食、爱心)──▶ idle
任意 ──右键菜单·抚摸──▶ loved(爱心粒子+扭动)──▶ idle
idle 持续 90s ──▶ sleeping(闭眼+Zzz)──任意交互──▶ watching
```

## 数据流

1. 拖入照片 → `CutoutProcessor` 输出透明背景 PNG(CVPixelBuffer→CGImage)。
2. `PoseAnalyzer` 检测左右眼/鼻子归一化坐标;置信度不足时 UI 让用户点两下标眼睛。
3. `PetProfile`(名字、抠图 PNG 路径、眼睛坐标、缩放)写入
   `~/Library/Application Support/CatOS/pets/<uuid>/`。
4. 启动时若有已保存宠物 → 直接生成桌宠窗口;否则进导入流程。

## 错误处理

- 抠图无前景:提示换照片。
- 眼睛检测失败:降级为手动标记,不阻塞流程。
- 配置文件损坏:忽略并回到导入流程,不崩溃。

## 测试

- 单元测试:几何计算(瞳孔偏移、角度)、BehaviorEngine 状态转移、PetProfile 编解码。
- 视觉/交互属 GUI 实测,提供 `swift run` 与打包脚本人工验证。

## 暂不做(YAGNI)

- 云端 AI 多角度重绘(留 `PoseGenerator` 协议扩展位)
- 音效、多宠物同屏、饥饿值养成系统
