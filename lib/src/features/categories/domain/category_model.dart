import 'package:isar/isar.dart';

part 'category_model.g.dart';

@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String name;

  late int colorValue;

  /// 分类类型：'event'（日程）或 'task'（待办）
  @Index()
  late String type;
}

