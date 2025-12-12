import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/task_repository.dart';
import '../domain/task_model.dart';

final taskListProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.watchTasks();
});

