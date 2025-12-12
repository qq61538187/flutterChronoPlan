import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/isar_database.dart';
import '../domain/task_model.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(isarProvider.future));
});

class TaskRepository {
  final Future<Isar> _dbFuture;

  TaskRepository(this._dbFuture);

  Future<Isar> get db => _dbFuture;

  Future<List<TaskModel>> getTasks() async {
    final isar = await db;
    return await isar.taskModels
        .where()
        .sortByIsCompleted()
        .thenByPriorityDesc()
        .thenByDueDate()
        .findAll();
  }

  Future<List<TaskModel>> searchTasks(String query) async {
    if (query.isEmpty) return [];
    final isar = await db;
    return await isar.taskModels
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .descriptionContains(query, caseSensitive: false)
        .sortByIsCompleted()
        .thenByPriorityDesc()
        .findAll();
  }
  
  Stream<List<TaskModel>> watchTasks() async* {
     final isar = await db;
     yield* isar.taskModels
        .where()
        .sortByIsCompleted()
        .thenByPriorityDesc()
        .thenByDueDate()
        .watch(fireImmediately: true);
  }

  Future<void> addTask(TaskModel task) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.taskModels.put(task);
    });
  }

  Future<void> updateTask(TaskModel task) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.taskModels.put(task);
    });
  }

  Future<void> deleteTask(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.taskModels.delete(id);
    });
  }
  
  Future<void> toggleTaskCompletion(TaskModel task) async {
      final isar = await db;
      task.isCompleted = !task.isCompleted;
      await isar.writeTxn(() async {
        await isar.taskModels.put(task);
      });
  }
}
