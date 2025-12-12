import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../calendar/presentation/widgets/event_list_item.dart';
import '../../tasks/presentation/task_screen.dart'; // 当前 TaskScreen 的条目组件是私有的，这里暂时用一个简化版展示
import '../application/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索日程或待办...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: searchResultsAsync.when(
                data: (results) {
                  if (_searchController.text.isEmpty) {
                    return const Center(child: Text('输入关键词开始搜索'));
                  }
                  if (results.isEmpty) {
                    return const Center(child: Text('未找到相关结果'));
                  }
                  return ListView(
                    children: [
                      if (results.events.isNotEmpty) ...[
                        _buildSectionHeader('相关日程 (${results.events.length})'),
                        ...results.events.map((e) => EventListItem(event: e)),
                        const SizedBox(height: 16),
                      ],
                      if (results.tasks.isNotEmpty) ...[
                        _buildSectionHeader('相关待办 (${results.tasks.length})'),
                        // 理想情况是复用待办列表条目组件；但 TaskScreen 里是私有组件，
                        // 这里先用一个简化版条目展示搜索结果。
                        ...results.tasks.map((t) => ListTile(
                          leading: Icon(
                            t.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                            color: t.isCompleted ? Colors.green : Colors.grey,
                          ),
                          title: Text(t.title),
                          subtitle: Text(t.description ?? ''),
                          trailing: t.dueDate != null ? Text(t.dueDate.toString().split(' ')[0]) : null,
                        )),
                      ],
                    ],
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
}

