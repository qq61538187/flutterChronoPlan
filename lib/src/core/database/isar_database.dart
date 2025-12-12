import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/calendar/domain/event_model.dart';
import '../../features/tasks/domain/task_model.dart';
import '../../features/categories/domain/category_model.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  if (Isar.instanceNames.isEmpty) {
    return await Isar.open(
      [EventModelSchema, TaskModelSchema, CategoryModelSchema],
      directory: dir.path,
    );
  }
  return Future.value(Isar.getInstance());
});

