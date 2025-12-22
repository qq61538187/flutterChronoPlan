import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:rrule/rrule.dart';
import 'package:lunar/lunar.dart'; // 农历相关（节日/农历重复）
import 'package:flutter/foundation.dart';
import '../../../core/database/isar_database.dart';
import '../domain/event_model.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(isarProvider.future));
});

class EventRepository {
  final Future<Isar> _dbFuture;

  EventRepository(this._dbFuture);

  Future<Isar> get db => _dbFuture;

  Future<List<EventModel>> getEventsForMonth(DateTime month) async {
    // 月视图查询：
    // - 普通日程：直接按时间范围查询
    // - 重复日程：取出所有重复规则，在内存中展开到当前月份
    
    final isar = await db;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

    // 1) 查询普通日程（非重复、非农历重复）
    final normalEvents = await isar.eventModels
        .filter()
        .recurrenceRuleIsNull()
        .and()
        .lunarRecurrenceIsNull() // 也排除农历重复
        .and()
        .group((q) => q
            .startTimeBetween(start, end)
            .or()
            .endTimeBetween(start, end))
        .sortByStartTime()
        .findAll();

    // 2) 查询所有重复日程（数量一般不会太大，个人应用可接受）
    final recurringEvents = await isar.eventModels
        .filter()
        .recurrenceRuleIsNotNull()
        .or()
        .lunarRecurrenceIsNotNull()
        .findAll();

    List<EventModel> expandedEvents = [];

    // 3) 展开重复日程到当前月份
    for (var event in recurringEvents) {
      if (event.recurrenceRule != null) {
        _expandRRule(event, start, end, expandedEvents);
      } else if (event.lunarRecurrence != null) {
        _expandLunarRecurrence(event, start, end, expandedEvents);
      }
    }

    // 4) 合并并排序
    final allEvents = [...normalEvents, ...expandedEvents];
    allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    assert(() {
      // 仅 Debug：帮助定位“2026-01-01 没出现”的问题
      if (start.year == 2026 && start.month == 1) {
        final jan1 = DateTime(2026, 1, 1);
        final hasJan1 = allEvents.any((e) => e.startTime.year == jan1.year && e.startTime.month == jan1.month && e.startTime.day == jan1.day);
        debugPrint('[getEventsForMonth] month=${start.year}-${start.month} all=${allEvents.length} expanded=${expandedEvents.length} hasJan1=$hasJan1');
        final candidates = recurringEvents.where((e) => (e.recurrenceRule ?? '').contains('BYMONTHDAY=1')).toList();
        for (final e in candidates) {
          debugPrint('  [candidate] id=${e.id} title=${e.title} start=${e.startTime.toIso8601String()} isUtc=${e.startTime.isUtc} rule=${e.recurrenceRule}');
        }
        final jan1Events = allEvents.where((e) => e.startTime.year == 2026 && e.startTime.month == 1 && e.startTime.day == 1).toList();
        for (final e in jan1Events) {
          debugPrint('  [jan1-instance] id=${e.id} title=${e.title} start=${e.startTime.toIso8601String()} rule=${e.recurrenceRule}');
        }
      }
      return true;
    }());
    
    return allEvents;
  }
  
  Future<List<EventModel>> getEventsForDay(DateTime day) async {
    final isar = await db;
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);

    // 与月视图类似：普通日程直接查；重复日程展开后再筛选
    final normalEvents = await isar.eventModels
        .filter()
        .recurrenceRuleIsNull()
        .and()
        .lunarRecurrenceIsNull()
        .and()
        .group((q) => q
            .startTimeBetween(start, end)
            .or()
            .endTimeBetween(start, end))
        .sortByStartTime()
        .findAll();

    final recurringEvents = await isar.eventModels
        .filter()
        .recurrenceRuleIsNotNull()
        .or()
        .lunarRecurrenceIsNotNull()
        .findAll();

    List<EventModel> expandedEvents = [];
    for (var event in recurringEvents) {
      if (event.recurrenceRule != null) {
        _expandRRule(event, start, end, expandedEvents);
      } else if (event.lunarRecurrence != null) {
        _expandLunarRecurrence(event, start, end, expandedEvents);
      }
    }

    final allEvents = [...normalEvents, ...expandedEvents];
    allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    return allEvents;
  }

  void _expandRRule(EventModel event, DateTime start, DateTime end, List<EventModel> outList) {
    try {
      // Ensure prefix exists if missing (for backward compatibility with bad data)
      String ruleStr = event.recurrenceRule!;
      if (!ruleStr.startsWith('RRULE:')) {
        ruleStr = 'RRULE:$ruleStr';
      }

      // 对于“每月固定日期/每年固定日期”这类简单规则，直接在本地生成实例，避免 rrule 在跨月/跨年边界出现偏差。
      // 目前你的数据属于：RRULE:FREQ=MONTHLY;BYMONTHDAY=1  => 必须生成 2026-01-01
      final ruleBody = ruleStr.substring('RRULE:'.length);
      if (_tryExpandSimpleRRuleFallback(event, ruleBody, start, end, outList)) {
        return;
      }
      
      final rrule = RecurrenceRule.fromString(ruleStr);
      
      // rrule 包要求 start/after/before 必须是 UTC（isUtc=true），否则会触发断言：
      // `start.isValidRruleDateTime`.
      // 同时为了避免跨月/跨年边界丢实例，这里在查询区间两端各留 1 天 buffer。
      final eventStartUtc = event.startTime.toUtc();
      final queryAfterUtc = start.toUtc().subtract(const Duration(days: 1));
      final queryBeforeUtc = end.toUtc().add(const Duration(days: 1));

      // rrule.getInstances 的断言要求 after >= start 且 before >= start 且 before >= after
      var effectiveAfterUtc = queryAfterUtc;
      if (effectiveAfterUtc.isBefore(eventStartUtc)) {
        effectiveAfterUtc = eventStartUtc;
      }
      final effectiveBeforeUtc = queryBeforeUtc;
      if (effectiveBeforeUtc.isBefore(eventStartUtc)) return;
      if (effectiveBeforeUtc.isBefore(effectiveAfterUtc)) return;

      final instances = rrule.getInstances(
        start: eventStartUtc,
        before: effectiveBeforeUtc,
        after: effectiveAfterUtc,
        includeAfter: true,
        includeBefore: true,
      );

      for (var inst in instances) {
        // 为每个实例创建一份“临时副本”，并保持原日程的时长不变
        final duration = event.endTime.difference(event.startTime);
        final instanceStart = inst.toLocal();
        final instanceEnd = instanceStart.add(duration);

        // 二次确认范围（rrule 可能返回更大的区间）
        final inRange = instanceStart.isBefore(end.add(const Duration(milliseconds: 1))) &&
            instanceEnd.isAfter(start.subtract(const Duration(milliseconds: 1)));
        if (inRange) {
           outList.add(
            EventModel()
              ..id = event.id // 保持原 ID，便于“编辑系列”（当前实现为编辑主记录）
              ..title = event.title
              ..description = event.description
              ..location = event.location
              ..priority = event.priority
              ..category = event.category
              ..startTime = instanceStart
              ..endTime = instanceEnd
              ..isAllDay = event.isAllDay
              ..recurrenceRule = event.recurrenceRule
              ..lunarRecurrence = event.lunarRecurrence
          );
        }
      }
    } catch (e) {
      // 这里常见原因：start/after/before 非 UTC，或历史数据 rule 缺失 RRULE: 前缀
      print('Error parsing RRULE (id=${event.id}, rule=${event.recurrenceRule}): $e');
    }
  }

  /// 处理常见简单规则（不依赖 rrule）：
  /// - FREQ=MONTHLY;BYMONTHDAY=...
  /// - FREQ=YEARLY;BYMONTH=...;BYMONTHDAY=...
  ///
  /// 返回 true 表示已处理并写入 outList；false 表示不匹配/交给 rrule 处理。
  bool _tryExpandSimpleRRuleFallback(
    EventModel event,
    String ruleBody,
    DateTime rangeStart,
    DateTime rangeEnd,
    List<EventModel> outList,
  ) {
    final props = <String, String>{};
    for (final part in ruleBody.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      props[part.substring(0, idx).toUpperCase()] = part.substring(idx + 1);
    }

    final freq = props['FREQ']?.toUpperCase();
    final byMonthDayRaw = props['BYMONTHDAY'];
    if (byMonthDayRaw == null || byMonthDayRaw.isEmpty) return false;

    // 只处理单日（我们 UI 目前也是单日）
    final byMonthDays = byMonthDayRaw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList(growable: false);
    if (byMonthDays.isEmpty) return false;

    // 目前仅支持一个 BYMONTHDAY（避免重复实例/排序问题）
    final byMonthDay = byMonthDays.first;

    // 复杂规则交给 rrule
    if (props.containsKey('BYDAY') ||
        props.containsKey('BYSETPOS') ||
        props.containsKey('BYWEEKNO') ||
        props.containsKey('BYYEARDAY')) {
      return false;
    }

    final duration = event.endTime.difference(event.startTime);
    final timeTemplate = event.startTime;

    bool inRange(DateTime s, DateTime e) =>
        s.isBefore(rangeEnd.add(const Duration(milliseconds: 1))) &&
        e.isAfter(rangeStart.subtract(const Duration(milliseconds: 1)));

    if (freq == 'MONTHLY') {
      // 系列起点过滤：
      // - 正常情况下使用 event.startTime（DTSTART 语义）
      // - 如果数据被编辑/导入后出现“规则=每月X号，但 startTime.day != X”的不一致，
      //   为了满足用户“固定日期（月/年）”的预期，改用 createdAt 作为系列起点（避免 1 号永远缺失）。
      final bool startMismatch = event.startTime.day != byMonthDay;
      final DateTime seriesNotBefore = startMismatch ? event.createdAt : event.startTime;

      // 从 rangeStart 的月份开始迭代到 rangeEnd 的月份（含）
      var y = rangeStart.year;
      var m = rangeStart.month;
      final endY = rangeEnd.year;
      final endM = rangeEnd.month;

      while (y < endY || (y == endY && m <= endM)) {
        final daysInMonth = DateTime(y, m + 1, 0).day;
        if (byMonthDay >= 1 && byMonthDay <= daysInMonth) {
          final instanceStart = DateTime(
            y,
            m,
            byMonthDay,
            timeTemplate.hour,
            timeTemplate.minute,
            timeTemplate.second,
            timeTemplate.millisecond,
            timeTemplate.microsecond,
          );

          // 实例不得早于 seriesNotBefore（见上方解释）
          if (!instanceStart.isBefore(seriesNotBefore)) {
            final instanceEnd = instanceStart.add(duration);
            if (inRange(instanceStart, instanceEnd)) {
              outList.add(
                EventModel()
                  ..id = event.id
                  ..title = event.title
                  ..description = event.description
                  ..location = event.location
                  ..priority = event.priority
                  ..category = event.category
                  ..startTime = instanceStart
                  ..endTime = instanceEnd
                  ..isAllDay = event.isAllDay
                  ..recurrenceRule = event.recurrenceRule
                  ..lunarRecurrence = event.lunarRecurrence
                  ..isCompleted = event.isCompleted,
              );
            }
          }
        }

        m += 1;
        if (m == 13) {
          m = 1;
          y += 1;
        }
      }

      return true;
    }

    if (freq == 'YEARLY') {
      final byMonthRaw = props['BYMONTH'];
      final byMonth = byMonthRaw == null ? null : int.tryParse(byMonthRaw.trim());
      if (byMonth == null || byMonth < 1 || byMonth > 12) return false;

      final bool startMismatch = event.startTime.month != byMonth || event.startTime.day != byMonthDay;
      final DateTime seriesNotBefore = startMismatch ? event.createdAt : event.startTime;

      for (var y = rangeStart.year; y <= rangeEnd.year; y++) {
        final daysInMonth = DateTime(y, byMonth + 1, 0).day;
        if (byMonthDay < 1 || byMonthDay > daysInMonth) continue;

        final instanceStart = DateTime(
          y,
          byMonth,
          byMonthDay,
          timeTemplate.hour,
          timeTemplate.minute,
          timeTemplate.second,
          timeTemplate.millisecond,
          timeTemplate.microsecond,
        );

        if (!instanceStart.isBefore(seriesNotBefore)) {
          final instanceEnd = instanceStart.add(duration);
          if (inRange(instanceStart, instanceEnd)) {
            outList.add(
              EventModel()
                ..id = event.id
                ..title = event.title
                ..description = event.description
                ..location = event.location
                ..priority = event.priority
                ..category = event.category
                ..startTime = instanceStart
                ..endTime = instanceEnd
                ..isAllDay = event.isAllDay
                ..recurrenceRule = event.recurrenceRule
                ..lunarRecurrence = event.lunarRecurrence
                ..isCompleted = event.isCompleted,
            );
          }
        }
      }
      return true;
    }

    return false;
  }

  /// 获取“展开后的所有日程”（含重复实例），默认展开未来 2 年，供清单页使用
  Future<List<EventModel>> getAllEventsExpanded({DateTime? start, DateTime? end}) async {
    final isar = await db;
    final raw = await isar.eventModels.where().findAll();

    final rangeStart = start ?? DateTime.now().subtract(const Duration(days: 7));
    final rangeEnd = end ?? DateTime.now().add(const Duration(days: 730));

    final List<EventModel> expanded = [];
    for (final e in raw) {
      if (e.recurrenceRule == null && e.lunarRecurrence == null) {
        // 普通日程：只保留范围内的
        if (e.startTime.isBefore(rangeEnd) && e.endTime.isAfter(rangeStart)) {
          expanded.add(e);
        }
      } else if (e.recurrenceRule != null) {
        _expandRRule(e, rangeStart, rangeEnd, expanded);
      } else if (e.lunarRecurrence != null) {
        _expandLunarRecurrence(e, rangeStart, rangeEnd, expanded);
      }
    }

    expanded.sort((a, b) => a.startTime.compareTo(b.startTime));

    assert(() {
      final jan1 = DateTime(2026, 1, 1);
      final hasJan1 = expanded.any((e) => e.startTime.year == jan1.year && e.startTime.month == jan1.month && e.startTime.day == jan1.day);
      debugPrint('[getAllEventsExpanded] total=${expanded.length} hasJan1=$hasJan1 range=${rangeStart.toIso8601String()}..${rangeEnd.toIso8601String()}');
      return true;
    }());
    return expanded;
  }

  void _expandLunarRecurrence(EventModel event, DateTime start, DateTime end, List<EventModel> outList) {
    // 格式： "LUNAR;MONTH=1;DAY=1"（例如农历正月初一）
    // 做法：遍历 [start, end] 的每一天，计算其农历并匹配目标农历日期
    
    // 解析目标农历日期
    final parts = event.lunarRecurrence!.split(';');
    int? targetMonth;
    int? targetDay;
    
    for (var p in parts) {
      if (p.startsWith('MONTH=')) targetMonth = int.tryParse(p.split('=')[1]);
      if (p.startsWith('DAY=')) targetDay = int.tryParse(p.split('=')[1]);
    }

    if (targetMonth == null || targetDay == null) return;

    // 说明：农历映射不线性，很难“跳跃式”计算；
    // 月视图最多 30~40 天，逐日检查成本很低
    
    for (var d = start; d.isBefore(end) || d.isAtSameMomentAs(end); d = d.add(const Duration(days: 1))) {
      final solar = Solar.fromDate(d);
      final lunar = solar.getLunar();
      
      if (lunar.getMonth() == targetMonth && lunar.getDay() == targetDay) {
         final duration = event.endTime.difference(event.startTime);
         // 复用原日程的时分（秒/毫秒在创建时即可归一化）
         final instanceStart = DateTime(d.year, d.month, d.day, event.startTime.hour, event.startTime.minute);
         final instanceEnd = instanceStart.add(duration);
         
         outList.add(
            EventModel()
              ..id = event.id
              ..title = event.title
              ..description = event.description
              ..location = event.location
              ..priority = event.priority
              ..category = event.category
              ..startTime = instanceStart
              ..endTime = instanceEnd
              ..isAllDay = event.isAllDay
              ..recurrenceRule = event.recurrenceRule
              ..lunarRecurrence = event.lunarRecurrence
          );
      }
    }
  }

  Future<List<EventModel>> searchEvents(String query, {Set<String>? categories}) async {
    final isar = await db;
    
    List<EventModel> allResults;
    
    if (query.isEmpty) {
      // 查询为空时，返回所有事件
      allResults = await isar.eventModels.where().findAll();
    } else {
      // 先获取所有匹配关键词的结果
      allResults = await isar.eventModels
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .descriptionContains(query, caseSensitive: false)
        .or()
        .locationContains(query, caseSensitive: false)
        .findAll();
    }
    
    // 如果指定了分类筛选，过滤结果
    if (categories != null && categories.isNotEmpty) {
      final filtered = allResults
          .where((event) => categories.contains(event.category))
          .toList();
      filtered.sort((a, b) => a.startTime.compareTo(b.startTime));
      return filtered;
    }
    
    allResults.sort((a, b) => a.startTime.compareTo(b.startTime));
    return allResults;
  }

  Future<List<EventModel>> getAllEvents() async {
    final isar = await db;
    return await isar.eventModels.where().sortByStartTime().findAll();
  }

  Future<void> addEvent(EventModel event) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.eventModels.put(event);
    });
  }

  Future<void> updateEvent(EventModel event) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.eventModels.put(event);
    });
  }

  Future<void> deleteEvent(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.eventModels.delete(id);
    });
  }
  
  Stream<List<EventModel>> watchEventsForDay(DateTime day) async* {
    // Isar watcher 不方便直接挂自定义“展开/过滤”逻辑；
    // 这里监听集合变更后重新计算当天数据（正确优先）
    final isar = await db;
    
    // 监听整个集合（性能略差，但对重复展开更可靠）
    yield* isar.eventModels.watchLazy(fireImmediately: true).asyncMap((_) async {
      return await getEventsForDay(day);
    });
  }
}
