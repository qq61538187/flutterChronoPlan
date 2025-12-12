import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../application/task_providers.dart';
import '../data/task_repository.dart';
import '../domain/task_model.dart';
import '../../calendar/presentation/widgets/add_event_dialog.dart';
import 'widgets/add_task_dialog.dart';

class TaskScreen extends ConsumerWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddTaskDialog(),
          );
        },
        label: const Text('新建待办'),
        icon: const Icon(Icons.add_task),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '待办清单',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('暂无待办事项', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _TaskListItem(task: task);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskListItem extends ConsumerWidget {
  final TaskModel task;

  const _TaskListItem({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AddTaskDialog(taskToEdit: task),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (val) {
               ref.read(taskRepositoryProvider).toggleTaskCompletion(task);
            },
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : null,
            ),
          ),
          subtitle: task.dueDate != null 
            ? Text('截止日期: ${DateFormat.yMMMd('zh_CN').format(task.dueDate!)}') 
            : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPriorityChip(context, task.priority) ?? const SizedBox(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Colors.blue),
                tooltip: '转为日程',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddEventDialog(
                      selectedDate: task.dueDate ?? DateTime.now(),
                      initialTitle: task.title,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () {
                  _confirmDelete(context, ref, task);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除待办'),
        content: const Text('确定要删除这个待办事项吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(taskRepositoryProvider).deleteTask(task.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget? _buildPriorityChip(BuildContext context, int priority) {
    Color color;
    String label;
    switch (priority) {
      case 2:
        color = Colors.red;
        label = '高';
        break;
      case 1:
        color = Colors.orange;
        label = '中';
        break;
      default:
        return null; // 低优先级不显示标签
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}
