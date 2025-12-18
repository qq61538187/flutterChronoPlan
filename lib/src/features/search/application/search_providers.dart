import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../calendar/data/event_repository.dart';
import '../../calendar/domain/event_model.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_model.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索类型：'all'（全部）、'event'（日程）、'task'（待办）
final searchTypeProvider = StateProvider<String>((ref) => 'all');

/// 选中的分类列表（用于筛选）
final selectedCategoriesProvider = StateProvider<Set<String>>((ref) => <String>{});

final searchResultsProvider = FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final searchType = ref.watch(searchTypeProvider);
  final selectedCategories = ref.watch(selectedCategoriesProvider);

  final eventRepo = ref.watch(eventRepositoryProvider);
  final taskRepo = ref.watch(taskRepositoryProvider);

  List<EventModel> events = [];
  List<TaskModel> tasks = [];

  // 根据搜索类型决定搜索哪些内容
  // 注意：只有选择了具体类型（非"全部"）时才应用分类筛选
  final shouldApplyCategoryFilter = searchType != 'all' && selectedCategories.isNotEmpty;
  final categoriesToFilter = shouldApplyCategoryFilter ? selectedCategories : null;

  if (searchType == 'all' || searchType == 'event') {
    events = await eventRepo.searchEvents(query, categories: categoriesToFilter);
  }
  
  if (searchType == 'all' || searchType == 'task') {
    tasks = await taskRepo.searchTasks(query, categories: categoriesToFilter);
  }

  return SearchResults(events: events, tasks: tasks);
});

class SearchResults {
  final List<EventModel> events;
  final List<TaskModel> tasks;

  SearchResults({required this.events, required this.tasks});
  
  bool get isEmpty => events.isEmpty && tasks.isEmpty;
}

