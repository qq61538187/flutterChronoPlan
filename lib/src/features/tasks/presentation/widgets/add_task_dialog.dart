import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/task_repository.dart';
import '../../domain/task_model.dart';
import '../../../categories/application/category_providers.dart';
import '../../../categories/domain/category_model.dart';

class AddTaskDialog extends ConsumerStatefulWidget {
  final TaskModel? taskToEdit;

  const AddTaskDialog({super.key, this.taskToEdit});

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _dueDate;
  int _priority = 1;
  String _selectedCategory = '默认';

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;
    _titleController = TextEditingController(text: task?.title);
    _descriptionController = TextEditingController(text: task?.description);
    _dueDate = task?.dueDate;
    _priority = task?.priority ?? 1;
    _selectedCategory = task?.category ?? '默认';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(taskCategoriesProvider);

    return AlertDialog(
      title: Text(widget.taskToEdit != null ? '编辑待办' : '新建待办'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '任务名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入任务名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          locale: const Locale('zh', 'CN'),
                        );
                        if (date != null) {
                          setState(() {
                            _dueDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '截止日期',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _dueDate != null 
                            ? "${_dueDate!.year}-${_dueDate!.month}-${_dueDate!.day}" 
                            : '无',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<int>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: '优先级',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('低')),
                        DropdownMenuItem(value: 1, child: Text('中')),
                        DropdownMenuItem(value: 2, child: Text('高')),
                      ],
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isNotEmpty && !categories.any((c) => c.name == _selectedCategory)) {
                      _selectedCategory = categories.first.name;
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: '分类', border: OutlineInputBorder()),
                    items: categories.map((c) => DropdownMenuItem(
                      value: c.name,
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, color: Color(c.colorValue), margin: const EdgeInsets.only(right: 8)),
                          Text(c.name),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('加载分类失败: $e'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '备注 (可选)',
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saveTask,
          child: Text(widget.taskToEdit != null ? '更新' : '保存'),
        ),
      ],
    );
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final repository = ref.read(taskRepositoryProvider);

      if (widget.taskToEdit != null) {
        final updatedTask = widget.taskToEdit!
          ..title = _titleController.text
          ..description = _descriptionController.text
          ..dueDate = _dueDate
          ..priority = _priority
          ..category = _selectedCategory
          ..updatedAt = DateTime.now();
        
        await repository.updateTask(updatedTask);
      } else {
        final newTask = TaskModel()
          ..title = _titleController.text
          ..description = _descriptionController.text
          ..dueDate = _dueDate
          ..priority = _priority
          ..category = _selectedCategory;

        await repository.addTask(newTask);
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

