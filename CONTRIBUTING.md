## 贡献指南

感谢你愿意参与 ChronoPlan 的改进！

### 提交 Issue
请尽量提供以下信息，便于快速定位问题：
- 操作系统与版本（macOS / Windows）
- Flutter 版本（`flutter --version`）
- 复现步骤（越具体越好）
- 期望结果 vs 实际结果
- 相关截图/日志（如有）

### 提交 PR
1. **先建 Issue**（建议）：描述要修复/新增的内容，方便对齐方向。
2. **保持改动聚焦**：一个 PR 只做一件事，便于 review。
3. **中文化**：界面文案与注释优先使用简体中文。
4. **代码风格**：遵守 `analysis_options.yaml` 与现有代码结构。
5. **生成代码**：若改动涉及 Isar/riverpod 生成文件，请运行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 开发与自测
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos
```

### 许可
提交 PR 即代表你同意你的贡献以项目 `LICENSE` 的许可方式发布。


