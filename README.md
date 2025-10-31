# ChillFlow - 专注声流

一个 macOS 菜单栏应用，通过番茄钟与沉浸音乐的融合，帮助用户高效进入并维持心流状态。

## 功能特性

- 🍅 **番茄钟计时器**：3个25分钟专注周期，前2个专注后休息5分钟，最后1个专注后休息30分钟
- 🎵 **自动音频同步**：专注时自动播放背景音乐，休息时自动停止，平滑淡入淡出
- 📊 **专注统计**：热力图展示一周的专注时长分布
- 🔕 **菜单栏常驻**：轻量级后台运行，不影响工作流程

## 系统要求

- macOS 12.0 (Monterey) 或更高版本
- Xcode 14.0 或更高版本

## 项目结构

```
ChillFlow/
├── ChillFlowApp.swift          # 应用入口和菜单栏设置
├── Models/
│   └── TimerState.swift         # 计时器状态模型
├── Managers/
│   ├── TimerManager.swift       # 番茄钟逻辑管理
│   ├── AudioManager.swift       # 音频播放和淡入淡出
│   └── StatsManager.swift       # 统计数据管理
├── Views/
│   ├── MainView.swift           # 主视图（Tab容器）
│   ├── ControlView.swift        # 控制面板
│   └── StatsView.swift          # 统计视图
└── Resources/
    └── Audio/                   # 音频文件目录（需要添加）
        ├── Focus-Track-01.mp3
        └── Focus-Track-02.mp3
```

## 安装和运行

### 1. 使用 Xcode 打开项目

```bash
open ChillFlow.xcodeproj
```

### 2. 添加音频文件

根据需求，应用需要内置2个专注音频文件：

1. 在 Xcode 项目中创建 `Resources/Audio/` 文件夹
2. 将以下音频文件添加到项目中（确保添加到 target）：
   - `Focus-Track-01.mp3` - 专注音乐（如轻微白噪音、Alpha波）
   - `Focus-Track-02.mp3` - 专注音乐（如环境雨声）

**注意**：音频文件必须：
- 格式为 MP3
- 文件名精确匹配：`Focus-Track-01.mp3` 和 `Focus-Track-02.mp3`
- 添加到 Xcode 项目的 Bundle Resources 中

### 3. 配置 Bundle Identifier

在 Xcode 的 Target Settings 中设置唯一的 Bundle Identifier（例如：`com.yourname.ChillFlow`）

### 4. 运行项目

1. 选择运行目标为 "My Mac"
2. 点击运行按钮或按 `Cmd+R`
3. 应用将在菜单栏显示叶子图标

## 使用说明

1. **开始专注**：点击菜单栏图标 → 点击"开始专注"按钮
2. **控制计时器**：
   - 暂停/继续：暂停当前计时
   - 跳过：立即结束当前阶段，进入下一阶段
   - 重置：停止当前循环，返回空闲状态
3. **调整音量**：使用底部的音量滑块
4. **查看统计**：切换到"统计"标签页，查看一周的专注热力图

## 技术实现

- **SwiftUI**：现代化UI框架
- **Combine**：响应式状态管理
- **AVFoundation**：音频播放和淡入淡出控制
- **UserDefaults**：数据持久化

## 开发计划

- [x] 番茄钟核心逻辑
- [x] 音频播放和淡入淡出
- [x] 菜单栏UI
- [x] 统计热力图
- [ ] 自定义番茄钟时长
- [ ] 更多音频轨道
- [ ] 通知提醒

## 许可证

MIT License

