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

  Future<List<TaskModel>> searchTasks(String query, {Set<String>? categories}) async {
    final isar = await db;
    
    List<TaskModel> allResults;
    
    if (query.isEmpty) {
      // 查询为空时，返回所有待办
      allResults = await isar.taskModels.where().findAll();
    } else {
      // 先获取所有匹配关键词的结果
      allResults = await isar.taskModels
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .descriptionContains(query, caseSensitive: false)
        .findAll();
    }
    
    // 如果指定了分类筛选，过滤结果
    if (categories != null && categories.isNotEmpty) {
      final filtered = allResults
          .where((task) => categories.contains(task.category))
          .toList();
      filtered.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.priority != b.priority) {
          return b.priority.compareTo(a.priority);
        }
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return 0;
      });
      return filtered;
    }
    
    allResults.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority);
      }
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return 0;
    });
    return allResults;
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
