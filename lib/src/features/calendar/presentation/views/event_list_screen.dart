import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart'; // 农历相关（历史实现曾在此展开农历重复）
import 'package:isar/isar.dart';
import '../../data/event_repository.dart';
import '../../domain/event_model.dart';

import '../widgets/event_list_item.dart';

import 'package:rrule/rrule.dart';

final allEventsProvider = StreamProvider.autoDispose<List<EventModel>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  
  // 监听数据库变化后重新拉取“展开后的所有日程”
  return repo.db.asStream().asyncExpand((isar) {
    return isar.eventModels.watchLazy(fireImmediately: true).asyncMap((_) async {
      // 2. 统一复用仓库的展开逻辑，避免“日历有/清单没有”或跨月跨年丢实例
      return repo.getAllEventsExpanded();
    });
  });
});

class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(allEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('所有日程'),
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('暂无日程'));
          }
          return ListView.builder(
            itemCount: events.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final event = events[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index == 0 || !_isSameDay(events[index - 1].startTime, event.startTime))
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
                      child: Text(
                        DateFormat.yMMMMEEEEd('zh_CN').format(event.startTime),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  EventListItem(event: event),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
