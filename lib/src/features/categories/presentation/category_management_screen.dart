import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../application/category_providers.dart';
import '../data/category_repository.dart';
import '../domain/category_model.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('分类管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '日程分类'),
              Tab(text: '待办分类'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoryList(type: 'event'),
            _CategoryList(type: 'task'),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            onPressed: () {
              final tabIndex = DefaultTabController.of(context).index;
              final type = tabIndex == 0 ? 'event' : 'task';
              _showAddCategoryDialog(context, ref, type);
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref, String type) {
    showDialog(
      context: context,
      builder: (context) => _AddCategoryDialog(type: type),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final String type;

  const _CategoryList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = type == 'event' ? eventCategoriesProvider : taskCategoriesProvider;
    final categoriesAsync = ref.watch(provider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('暂无分类'));
        }
        return ListView.builder(
          itemCount: categories.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final category = categories[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(category.colorValue),
                  radius: 12,
                ),
                title: Text(category.name),
                trailing: category.name == '默认' 
                  ? const Tooltip(message: '默认分类不可删除', child: Icon(Icons.lock_outline, color: Colors.grey))
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () {
                        _confirmDelete(context, ref, category, categories);
                      },
                    ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryModel category, List<CategoryModel> allCategories) async {
    final repo = ref.read(categoryRepositoryProvider);
    final count = await repo.countDataInCategory(category.name, category.type);

    if (count > 0 && context.mounted) {
      showDialog(
        context: context,
        builder: (context) => _DeleteCategoryDialog(
          category: category,
          count: count,
          allCategories: allCategories,
          onMove: (targetCategory) {
             repo.moveDataAndDeleteCategory(category.id, category.name, targetCategory, category.type);
             Navigator.pop(context);
          },
          onDeleteAll: () {
             repo.deleteCategoryAndData(category.id, category.name, category.type);
             Navigator.pop(context);
          },
        ),
      );
    } else if (context.mounted) {
      // 普通删除流程
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除分类'),
          content: const Text('确定要删除这个分类吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                repo.deleteCategory(category.id);
                Navigator.pop(context);
              },
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }
  }
}

class _DeleteCategoryDialog extends StatefulWidget {
  final CategoryModel category;
  final int count;
  final List<CategoryModel> allCategories;
  final Function(String) onMove;
  final VoidCallback onDeleteAll;

  const _DeleteCategoryDialog({
    required this.category,
    required this.count,
    required this.allCategories,
    required this.onMove,
    required this.onDeleteAll,
  });

  @override
  State<_DeleteCategoryDialog> createState() => _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends State<_DeleteCategoryDialog> {
  String? _targetCategory;

  @override
  void initState() {
    super.initState();
    // 默认迁移到“默认”分类；若不存在则选择第一个可用分类
    final others = widget.allCategories.where((c) => c.id != widget.category.id).toList();
    if (others.any((c) => c.name == '默认')) {
      _targetCategory = '默认';
    } else if (others.isNotEmpty) {
      _targetCategory = others.first.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除分类'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('该分类下包含 ${widget.count} 条数据，请选择操作：'),
          const SizedBox(height: 16),
          const Text('是否将数据移动到其他分类？', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _targetCategory,
            items: widget.allCategories
                .where((c) => c.id != widget.category.id)
                .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                .toList(),
            onChanged: (val) => setState(() => _targetCategory = val),
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: '目标分类'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: widget.onDeleteAll,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('否，直接清空'),
        ),
        FilledButton(
          onPressed: _targetCategory != null ? () => widget.onMove(_targetCategory!) : null,
          child: const Text('是，移动并删除'),
        ),
      ],
    );
  }
}

class _AddCategoryDialog extends ConsumerStatefulWidget {
  final String type;

  const _AddCategoryDialog({required this.type});

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.type == 'event' ? '新建日程分类' : '新建待办分类'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '分类名称',
                  border: OutlineInputBorder(),
                  helperText: '仅支持中英文、数字、下划线、减号',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入名称';
                  }
                  // 校验规则：中文/英文/数字/下划线/连字符
                  final regex = RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9_\-]+$');
                  if (!regex.hasMatch(value)) {
                    return '包含非法字符';
                  }
                  if (value == '默认') return '不能使用“默认”作为名称';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('选择颜色：'),
                  GestureDetector(
                    onTap: () {
                      _showColorPicker(context);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: _saveCategory,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newCategory = CategoryModel()
          ..name = _nameController.text
          ..type = widget.type
          ..colorValue = _selectedColor.value;

        await ref.read(categoryRepositoryProvider).addCategory(newCategory);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
