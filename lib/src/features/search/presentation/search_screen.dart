import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../calendar/presentation/widgets/event_list_item.dart';
import '../../categories/application/category_providers.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_model.dart';
import '../application/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  bool _isFilterExpanded = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final searchType = ref.watch(searchTypeProvider);
    final selectedCategories = ref.watch(selectedCategoriesProvider);
    
    // 根据搜索类型获取对应的分类列表
    final categoriesAsync = searchType == 'event' 
        ? ref.watch(eventCategoriesProvider)
        : searchType == 'task'
            ? ref.watch(taskCategoriesProvider)
            : null;

    return Scaffold(
      body: Column(
        children: [
          // 搜索栏和筛选器区域
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 搜索输入框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索日程或待办...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                    setState(() {}); // 更新清除按钮显示
                  },
                ),
                const SizedBox(height: 12),
                // 筛选器卡片（可折叠）
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // 筛选器标题栏（可点击折叠）
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isFilterExpanded = !_isFilterExpanded;
                          });
                        },
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '筛选条件',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const Spacer(),
                              // 显示当前筛选状态
                              if (searchType != 'all' || selectedCategories.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${searchType == 'all' ? '全部' : searchType == 'event' ? '日程' : '待办'}${selectedCategories.isNotEmpty ? ' · ${selectedCategories.length}个分类' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              AnimatedRotation(
                                turns: _isFilterExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 筛选器内容（可折叠）
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: _isFilterExpanded
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    // 类型选择
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.filter_list,
                                          size: 18,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '搜索类型',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SegmentedButton<String>(
                                      segments: [
                                        ButtonSegment(
                                          value: 'all',
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.apps, size: 16),
                                              SizedBox(width: 4),
                                              Text('全部'),
                                            ],
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: 'event',
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.calendar_today, size: 16),
                                              SizedBox(width: 4),
                                              Text('日程'),
                                            ],
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: 'task',
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.check_circle_outline, size: 16),
                                              SizedBox(width: 4),
                                              Text('待办'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      selected: {searchType},
                                      onSelectionChanged: (Set<String> newSelection) {
                                        ref.read(searchTypeProvider.notifier).state = newSelection.first;
                                        // 切换类型时清空分类选择
                                        ref.read(selectedCategoriesProvider.notifier).state = <String>{};
                                      },
                                    ),
                                    // 分类选择（当选择了待办或日程时显示）
                                    if (categoriesAsync != null) ...[
                                      const SizedBox(height: 16),
                                      categoriesAsync.when(
                                        data: (categories) {
                                          if (categories.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.category,
                                                    size: 18,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '分类筛选',
                                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (selectedCategories.isNotEmpty)
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        ref.read(selectedCategoriesProvider.notifier).state = <String>{};
                                                      },
                                                      icon: const Icon(Icons.clear_all, size: 16),
                                                      label: const Text('清空'),
                                                      style: TextButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: categories.map((category) {
                                                  final isSelected = selectedCategories.contains(category.name);
                                                  final categoryColor = Color(category.colorValue);
                                                  return FilterChip(
                                                    label: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 12,
                                                          height: 12,
                                                          decoration: BoxDecoration(
                                                            color: categoryColor,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(category.name),
                                                      ],
                                                    ),
                                                    selected: isSelected,
                                                    onSelected: (selected) {
                                                      final current = Set<String>.from(selectedCategories);
                                                      if (selected) {
                                                        current.add(category.name);
                                                      } else {
                                                        current.remove(category.name);
                                                      }
                                                      ref.read(selectedCategoriesProvider.notifier).state = current;
                                                    },
                                                    selectedColor: categoryColor.withOpacity(0.2),
                                                    checkmarkColor: categoryColor,
                                                    side: BorderSide(
                                                      color: isSelected 
                                                          ? categoryColor 
                                                          : Colors.grey.shade300,
                                                      width: isSelected ? 1.5 : 1,
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          );
                                        },
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, __) => const SizedBox.shrink(),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 搜索结果区域
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: searchResultsAsync.when(
                data: (results) {
                  if (results.isEmpty) {
                    return const Center(child: Text('未找到相关结果'));
                  }
                  return ListView(
                    children: [
                      if (results.events.isNotEmpty) ...[
                        _buildSectionHeader('相关日程 (${results.events.length})'),
                        ...results.events.map((e) => EventListItem(
                          event: e,
                          onCompletionChanged: () {
                            // 刷新搜索结果
                            ref.invalidate(searchResultsProvider);
                          },
                        )),
                        const SizedBox(height: 16),
                      ],
                      if (results.tasks.isNotEmpty) ...[
                        _buildSectionHeader('相关待办 (${results.tasks.length})'),
                        // 理想情况是复用待办列表条目组件；但 TaskScreen 里是私有组件，
                        // 这里先用一个简化版条目展示搜索结果。
                        ...results.tasks.map((t) => _buildTaskListItem(t, ref)),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildTaskListItem(TaskModel task, WidgetRef ref) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (val) async {
            // 切换完成状态
            await ref.read(taskRepositoryProvider).toggleTaskCompletion(task);
            // 刷新搜索结果
            ref.invalidate(searchResultsProvider);
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: task.description != null && task.description!.isNotEmpty
            ? Text(task.description!)
            : null,
        trailing: task.dueDate != null 
            ? Text(task.dueDate.toString().split(' ')[0]) 
            : null,
      ),
    );
  }
}

