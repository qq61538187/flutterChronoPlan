import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/event_repository.dart';
import '../domain/event_model.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dayEventsProvider = StreamProvider.autoDispose.family<List<EventModel>, DateTime>((ref, date) {
  final repository = ref.watch(eventRepositoryProvider);
  return repository.watchEventsForDay(date);
});

