import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../../../core/database/isar_database.dart';
import '../../calendar/domain/event_model.dart';
import '../../tasks/domain/task_model.dart';
import '../../categories/domain/category_model.dart';

final dataTransferServiceProvider = Provider<DataTransferService>((ref) {
  return DataTransferService(ref.watch(isarProvider.future));
});

class DataTransferService {
  final Future<Isar> _dbFuture;

  DataTransferService(this._dbFuture);

  Future<Isar> get db => _dbFuture;

  Future<String?> exportData() async {
    try {
      final isar = await db;
      final events = await isar.eventModels.where().findAll();
      final tasks = await isar.taskModels.where().findAll();
      final categories = await isar.categoryModels.where().findAll();

      final data = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'events': events.map((e) => _eventToJson(e)).toList(),
        'tasks': tasks.map((t) => _taskToJson(t)).toList(),
        'categories': categories.map((c) => _categoryToJson(c)).toList(),
      };

      final jsonString = jsonEncode(data);
      
      // 打开保存对话框
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出数据',
        fileName: 'chronoplan_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);
        return outputFile;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入数据',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString) as Map<String, dynamic>;

        final isar = await db;

        // 解析日程
        final List<dynamic> eventsJson = data['events'] ?? [];
        final events = eventsJson.map((e) => _jsonToEvent(e)).toList();

        // 解析待办
        final List<dynamic> tasksJson = data['tasks'] ?? [];
        final tasks = tasksJson.map((t) => _jsonToTask(t)).toList();

        // 解析分类
        final List<dynamic> categoriesJson = data['categories'] ?? [];
        final categories = categoriesJson.map((c) => _jsonToCategory(c)).toList();

        await isar.writeTxn(() async {
          // 说明：
          // - 当前导入逻辑为“追加/更新”而非“清空覆盖”
          // - 日程/待办：直接 putAll（Isar 自增 ID，若不清空会产生重复记录）
          // - 分类：按 (type + name) 唯一键合并；若已存在则覆盖颜色
          
          await isar.eventModels.putAll(events);
          await isar.taskModels.putAll(tasks);
          
          for (var c in categories) {
             final exists = await isar.categoryModels.filter().typeEqualTo(c.type).nameEqualTo(c.name).findFirst();
             if (exists != null) {
               // 已存在：覆盖颜色
               c.id = exists.id; // 复用 ID 做更新
               await isar.categoryModels.put(c);
             } else {
               await isar.categoryModels.put(c);
             }
          }
        });
        
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  // 手写 JSON 映射（避免引入额外序列化依赖）
  Map<String, dynamic> _eventToJson(EventModel e) => {
    'title': e.title,
    'description': e.description,
    'startTime': e.startTime.toIso8601String(),
    'endTime': e.endTime.toIso8601String(),
    'isAllDay': e.isAllDay,
    'location': e.location,
    'priority': e.priority,
    'category': e.category,
    'recurrenceRule': e.recurrenceRule,
    'isCompleted': e.isCompleted,
    'createdAt': e.createdAt.toIso8601String(),
    'updatedAt': e.updatedAt.toIso8601String(),
  };

  EventModel _jsonToEvent(dynamic json) {
    return EventModel()
      ..title = json['title']
      ..description = json['description']
      ..startTime = DateTime.parse(json['startTime'])
      ..endTime = DateTime.parse(json['endTime'])
      ..isAllDay = json['isAllDay'] ?? false
      ..location = json['location']
      ..priority = json['priority'] ?? 1
      ..category = json['category'] ?? 'Personal'
      ..recurrenceRule = json['recurrenceRule']
      ..isCompleted = json['isCompleted'] ?? false
      ..createdAt = json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()
      ..updatedAt = json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now();
  }

  Map<String, dynamic> _taskToJson(TaskModel t) => {
    'title': t.title,
    'description': t.description,
    'dueDate': t.dueDate?.toIso8601String(),
    'priority': t.priority,
    'category': t.category,
    'isCompleted': t.isCompleted,
    'linkedEventId': t.linkedEventId,
    'createdAt': t.createdAt.toIso8601String(),
    'updatedAt': t.updatedAt.toIso8601String(),
  };

  TaskModel _jsonToTask(dynamic json) {
    return TaskModel()
      ..title = json['title']
      ..description = json['description']
      ..dueDate = json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null
      ..priority = json['priority'] ?? 1
      ..category = json['category'] ?? 'Personal'
      ..isCompleted = json['isCompleted'] ?? false
      ..linkedEventId = json['linkedEventId']
      ..createdAt = json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()
      ..updatedAt = json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now();
  }

  Map<String, dynamic> _categoryToJson(CategoryModel c) => {
    'name': c.name,
    'colorValue': c.colorValue,
    'type': c.type,
  };

  CategoryModel _jsonToCategory(dynamic json) {
    return CategoryModel()
      ..name = json['name']
      ..colorValue = json['colorValue']
      ..type = json['type'];
  }
}

