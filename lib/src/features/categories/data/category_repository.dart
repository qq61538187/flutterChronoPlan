import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/isar_database.dart';
import '../domain/category_model.dart';
import '../../calendar/domain/event_model.dart';
import '../../tasks/domain/task_model.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(isarProvider.future));
});

class CategoryRepository {
  final Future<Isar> _dbFuture;

  CategoryRepository(this._dbFuture);

  Future<Isar> get db => _dbFuture;

  Future<List<CategoryModel>> getCategoriesByType(String type) async {
    final isar = await db;
    return await isar.categoryModels.filter().typeEqualTo(type).findAll();
  }

  Stream<List<CategoryModel>> watchCategoriesByType(String type) async* {
    final isar = await db;
    yield* isar.categoryModels.filter().typeEqualTo(type).watch(fireImmediately: true);
  }

  Future<void> addCategory(CategoryModel category) async {
    final isar = await db;
    
    // 校验：同类型下名称不能重复
    final count = await isar.categoryModels
        .filter()
        .typeEqualTo(category.type)
        .nameEqualTo(category.name)
        .count();
        
    if (count > 0) {
      throw Exception('在该模块下已存在相同名称的分类');
    }

    await isar.writeTxn(() async {
      await isar.categoryModels.put(category);
    });
  }

  Future<void> deleteCategory(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.categoryModels.delete(id);
    });
  }
  
  // 初始化默认分类（首次启动/分类为空时）
  Future<void> initDefaultCategories() async {
    final isar = await db;
    
    // 确保“日程”的默认分类存在
    final defaultEvent = await isar.categoryModels.filter().typeEqualTo('event').nameEqualTo('默认').findFirst();
    if (defaultEvent == null) {
      await isar.writeTxn(() async {
        await isar.categoryModels.put(CategoryModel()..name = '默认'..type = 'event'..colorValue = 0xFF9E9E9E);
      });
    }

    // 确保“待办”的默认分类存在
    final defaultTask = await isar.categoryModels.filter().typeEqualTo('task').nameEqualTo('默认').findFirst();
    if (defaultTask == null) {
      await isar.writeTxn(() async {
        await isar.categoryModels.put(CategoryModel()..name = '默认'..type = 'task'..colorValue = 0xFF9E9E9E);
      });
    }

    // 初始填充（仅在分类非常少时）
    // 说明：用户可能会删除非默认分类；这里仅在“只有默认分类/几乎为空”时补充一些常用分类
    
    final count = await isar.categoryModels.count();
    if (count <= 2) { // 仅默认分类或为空
       final extraEvents = [
        CategoryModel()..name = '工作'..type = 'event'..colorValue = 0xFF2196F3,
        CategoryModel()..name = '生活'..type = 'event'..colorValue = 0xFF4CAF50,
      ];
      final extraTasks = [
        CategoryModel()..name = '工作'..type = 'task'..colorValue = 0xFF2196F3,
      ];
      
      // 添加前再次检查冲突
      await isar.writeTxn(() async {
        for (var c in extraEvents) {
          if (await isar.categoryModels.filter().typeEqualTo('event').nameEqualTo(c.name).isEmpty()) {
             await isar.categoryModels.put(c);
          }
        }
        for (var c in extraTasks) {
          if (await isar.categoryModels.filter().typeEqualTo('task').nameEqualTo(c.name).isEmpty()) {
             await isar.categoryModels.put(c);
          }
        }
      });
    }
  }

  Future<int> countDataInCategory(String categoryName, String type) async {
    final isar = await db;
    if (type == 'event') {
      return await isar.eventModels.filter().categoryEqualTo(categoryName).count();
    } else {
      return await isar.taskModels.filter().categoryEqualTo(categoryName).count();
    }
  }

  Future<void> moveDataAndDeleteCategory(Id categoryId, String oldName, String newName, String type) async {
    final isar = await db;
    await isar.writeTxn(() async {
      if (type == 'event') {
        final events = await isar.eventModels.filter().categoryEqualTo(oldName).findAll();
        for (var e in events) {
          e.category = newName;
          await isar.eventModels.put(e);
        }
      } else {
        final tasks = await isar.taskModels.filter().categoryEqualTo(oldName).findAll();
        for (var t in tasks) {
          t.category = newName;
          await isar.taskModels.put(t);
        }
      }
      await isar.categoryModels.delete(categoryId);
    });
  }

  Future<void> deleteCategoryAndData(Id categoryId, String categoryName, String type) async {
    final isar = await db;
    await isar.writeTxn(() async {
      if (type == 'event') {
        await isar.eventModels.filter().categoryEqualTo(categoryName).deleteAll();
      } else {
        await isar.taskModels.filter().categoryEqualTo(categoryName).deleteAll();
      }
      await isar.categoryModels.delete(categoryId);
    });
  }
}
