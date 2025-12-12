import 'package:isar/isar.dart';

part 'task_model.g.dart';

@collection
class TaskModel {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  String? description;

  /// 截止日期（可为空）
  @Index()
  DateTime? dueDate;

  /// 优先级：0=低，1=中，2=高
  @Index()
  int priority = 1;

  /// 分类
  @Index()
  String category = 'Personal';

  bool isCompleted = false;

  /// 若由待办转为日程/或与日程关联，则记录对应日程 ID
  int? linkedEventId;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

