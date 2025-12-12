import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/isar_database.dart';
import '../../calendar/domain/event_model.dart';
import '../../tasks/domain/task_model.dart';
import '../application/settings_providers.dart';
import '../data/data_transfer_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text(
            '设置',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          
          _buildSectionHeader(context, '外观'),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).state = val!,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).state = val!,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).state = val!,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(context, '数据管理'),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('导出备份'),
                  subtitle: const Text('将所有数据导出为 JSON 文件'),
                  onTap: () => _exportData(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入备份'),
                  subtitle: const Text('从 JSON 文件恢复数据'),
                  onTap: () => _importData(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('清除所有数据', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('删除所有日程和待办事项，此操作无法撤销'),
                  onTap: () => _confirmClearData(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(context, '关于'),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('ChronoPlan'),
              subtitle: Text('版本 0.1.0\n基于 Flutter 构建的桌面日程管理应用'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _confirmClearData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('警告'),
        content: const Text('确定要清空所有数据吗？\n日程和待办事项将被永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _clearAllData(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有数据已清除')),
                );
                // Refresh providers by invalidating them if needed, 
                // but Isar streams usually update automatically.
              }
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(WidgetRef ref) async {
    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() async {
      await isar.eventModels.clear();
      await isar.taskModels.clear();
    });
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref.read(dataTransferServiceProvider).exportData();
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('数据已导出至: $path')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final success = await ref.read(dataTransferServiceProvider).importData();
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据导入成功')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

