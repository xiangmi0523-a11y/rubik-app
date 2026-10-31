# 魔方 App（Flutter / iOS）

- **自由玩**：3D 魔方（puzzle_cube），手指拖拽转层、空白处拖动旋转视角；打乱后转第一下自动开始计时，还原后自动停止并记录成绩；点击计时器可手动计时（实体魔方用）。
- **填色求解**：按展开图填六面颜色 → 校验（颜色数量 / 不可能的块 / 翻棱 / 拧角 / 奇偶）→ cuber（Kociemba 两阶段算法）在后台 Isolate 求解 → 3D 动画逐步演示（播放、暂停、上一步、下一步、点击步骤跳转）。
- **成绩**：单次成绩、最佳、平均、当前/最佳 ao5、ao12（WCA 去头尾平均），左滑删除。
- **架构**：Riverpod 状态管理，feature-first 目录。

## 目录结构

```
lib/
  main.dart / app.dart
  core/
    cube/cube_facelets.dart        # puzzle_cube <-> cuber 坐标与转动映射
    prefs/shared_prefs_provider.dart
    utils/time_format.dart
  features/
    home/presentation/             # 底部导航
    free_play/application|presentation
    solver/domain|data|application|presentation
    stats/domain|data|application|presentation
test/                              # 映射、校验、ao5/ao12、播放、冒烟测试
```

## 魔方朝向约定

白色中心朝上、绿色中心朝前（红在右）。puzzle_cube 枚举名与渲染出来的面并不一致（例如它的 `u` 实际转的是画面中的底层），
`CubeNotation` 中的映射表是根据实际渲染结果推导并由测试验证的。

## 在手机上拿到安装包

推送到 GitHub 后，Actions 的 `CI` 工作流会：分析 + 测试 → 在 macOS 上 `flutter build ios --no-codesign`，
产物 `rubik_app_unsigned_ipa` 可在 Actions 运行页面下载，用 AltStore / Sideloadly / 巨魔等自签后安装。
