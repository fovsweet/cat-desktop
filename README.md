# CatOS 🐾 — 把你的宠物养在桌面上

上传一张猫/狗照片,CatOS 在本地抠图、定位眼睛,然后在桌面生成一只
**会用眼神跟着你鼠标走**的桌宠。完全离线,不需要任何 API key 或系统权限。

## 功能

| 交互 | 效果 |
|------|------|
| 移动鼠标 | 瞳孔跟随视线 + 身体朝鼠标方向轻微倾斜 |
| 左键单击宠物 | 伸出毛色匹配的爪子拍向光标 |
| 快速连点 | 整只宠物扑过去捕捉鼠标,落地冒爱心 |
| 右键 → 投喂 | 小鱼干🐟 / 鸡腿🍗 / 牛奶🥛 落地,低头进食 |
| 右键 → 抚摸 | 开心扭动 + 爱心粒子 |
| 90 秒无人理 | 闭眼打盹飘 Zzz,鼠标靠近或点击会醒 |
| 按住拖动 | 把宠物摆到屏幕任意位置 |

菜单栏 🐾 图标可随时显示宠物、更换照片或退出。

## 运行

```bash
swift run CatOS            # 开发运行
./scripts/make_app.sh      # 打包成 dist/CatOS.app
```

首次启动会打开导入窗口:拖入照片 → 自动抠图(Vision 前景分割)→
自动检测眼睛位置(猫狗身体姿态识别,可手动微调)→ 放到桌面。

## 技术

- **抠图**:`VNGenerateForegroundInstanceMaskRequest`,本地完成
- **眼睛定位**:`VNDetectAnimalBodyPoseRequest`(支持猫/狗),失败时手动标记兜底
- **动画**:2.5D 木偶 —— 抠图作身体层,叠加程序化眼睛/爪子/粒子 CALayer
- **鼠标跟踪**:轮询 `NSEvent.mouseLocation`,无需辅助功能权限
- **窗口**:透明无边框 `NSPanel`,置顶、全空间可见、不抢焦点

要求 macOS 14+。

## 自测工具

```bash
# 处理管线自测:输出抠图 + 眼睛标记预览图;--seed 直接写入宠物存档
.build/debug/CatOS --selftest <照片> <输出目录> [--seed]

# 交互演示模式:进程内驱动全部交互并自动截图(截图需要录屏权限)
CATOS_DEMO=1 CATOS_DEMO_OUT=/tmp/demo .build/debug/CatOS
```

```bash
swift test    # 单元 + 集成测试(集成测试使用 cat_png/ 下的真实照片)
```

## 结构

```
Sources/CatOSKit/
├── App/         AppDelegate、菜单栏、SelfTest、DemoDirector
├── Model/       PetProfile、PetStore(Application Support 持久化)
├── Processing/  CutoutProcessor(抠图)、PoseAnalyzer(眼睛检测)
├── Onboarding/  导入窗口(SwiftUI)
└── Pet/         PetView(图层木偶)、BehaviorEngine(状态机)、
                 PetWindowController、MouseTracker、PetGeometry
```

设计文档见 `docs/superpowers/specs/`。
