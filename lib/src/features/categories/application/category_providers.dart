import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/category_repository.dart';
import '../domain/category_model.dart';

final eventCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  // Ensure defaults are initialized (lazy way, ideally done at startup)
  repo.initDefaultCategories();
  return repo.watchCategoriesByType('event');
});

final taskCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchCategoriesByType('task');
});

