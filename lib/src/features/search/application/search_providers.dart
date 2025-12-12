import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../calendar/data/event_repository.dart';
import '../../calendar/domain/event_model.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_model.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) {
    return SearchResults(events: [], tasks: []);
  }

  final eventRepo = ref.watch(eventRepositoryProvider);
  final taskRepo = ref.watch(taskRepositoryProvider);

  final events = await eventRepo.searchEvents(query);
  final tasks = await taskRepo.searchTasks(query);

  return SearchResults(events: events, tasks: tasks);
});

class SearchResults {
  final List<EventModel> events;
  final List<TaskModel> tasks;

  SearchResults({required this.events, required this.tasks});
  
  bool get isEmpty => events.isEmpty && tasks.isEmpty;
}

