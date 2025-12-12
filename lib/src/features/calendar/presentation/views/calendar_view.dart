import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import '../../application/calendar_providers.dart';
import '../../domain/event_model.dart';
import '../widgets/event_list_item.dart';
import '../widgets/add_event_dialog.dart';
import '../../data/event_repository.dart'; // 用于加载 marker（月视图事件）

import 'event_list_screen.dart';

// 月视图右下角“X个日程”的数据来源（marker）
// 说明：
// - 逐日查询开销大，因此按“月份”批量取回，再在内存里按天过滤
// - TableCalendar 通过 eventLoader(day) 请求某一天的事件列表，用它来驱动 marker

/// 月份 marker 数据：用 Stream 监听 DB 变化，确保新增/编辑后 marker 立即更新；
/// 同时 key 必须是“月份起始日(YYYY-MM-01)”，避免选中不同日期导致同月反复刷新引起数量错乱。
final monthEventsLoaderProvider = StreamProvider.family<List<EventModel>, DateTime>((ref, monthStart) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.db.asStream().asyncExpand((isar) {
    return isar.eventModels.watchLazy(fireImmediately: true).asyncMap((_) async {
      return repo.getEventsForMonth(monthStart);
    });
  });
});

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now(); // 自定义头部年/月选择器依赖它
  
  @override
  void initState() {
    super.initState();
    // 初始聚焦日期与“当前选中日期”保持一致
    _focusedDay = ref.read(selectedDateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(dayEventsProvider(selectedDate));
    
    // 监听当月事件（key 归一到 YYYY-MM-01，避免选中日期变化导致同月反复刷新）
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEventsAsync = ref.watch(monthEventsLoaderProvider(monthStart));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddEventDialog(selectedDate: selectedDate),
          );
        },
        label: const Text('新建日程'),
        icon: const Icon(Icons.add),
      ),
      body: Row(
        children: [
          // 左侧：日历
          Expanded(
            flex: 3, // 给日历更多宽度
            child: Card(
              margin: const EdgeInsets.all(16),
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildCustomHeader(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: LayoutBuilder( // 用于拿到可用尺寸，计算正方形格子
                        builder: (context, constraints) {
                          // 日期格子保持“正方形”且不变窄：优先占满可用宽度，用宽度/7 计算 cellSize。
                          // 如果高度不够，会导致 TableCalendar 内部 Column overflow；这里改为“高度不够时可滚动”，保证不报错。
                          const daysOfWeekHeight = 40.0;
                          final cellSize = constraints.maxWidth / 7;
                          final desiredCalendarHeight = daysOfWeekHeight + cellSize * 6;

                          Widget calendar = TableCalendar(
                            locale: 'zh_CN',
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) {
                              return isSameDay(selectedDate, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                              });
                              ref.read(selectedDateProvider.notifier).state = selectedDay;
                            },
                            onPageChanged: (focusedDay) {
                              setState(() {
                                _focusedDay = focusedDay;
                              });
                            },
                            headerVisible: false, // 隐藏 TableCalendar 默认头部（使用自定义头部）
                            daysOfWeekHeight: daysOfWeekHeight,
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(fontSize: 16, color: Colors.black87),
                              weekendStyle: TextStyle(fontSize: 16, color: Colors.red),
                            ),
                            rowHeight: cellSize, // 正方形格子
                        
                        // marker：当天有哪些事件（用于显示“X个日程”）
                        eventLoader: (day) {
                          // 这个回调会被频繁调用，必须同步且足够快；
                          // 依赖上面按月预取的 monthEventsAsync，在内存中过滤当天事件。
                          return monthEventsAsync.when(
                            data: (events) {
                              // 事件在仓库层已对“重复规则”展开到当月；这里仅按天过滤
                              return events.where((e) => isSameDay(e.startTime, day)).toList();
                            },
                            loading: () => [],
                            error: (_, __) => [],
                          );
                        },
                        
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false),
                          selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, true),
                          todayBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false, isToday: true),
                          outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false, isOutside: true),
                          
                          // 自定义 marker 样式
                          markerBuilder: (context, day, events) {
                            if (events.isEmpty) return null;
                            return Positioned(
                              bottom: 2, // 适配正方形格子的底部间距
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${events.length}个日程',
                                  style: const TextStyle(color: Colors.white, fontSize: 9),
                                ),
                              ),
                            );
                          },
                        ),
                          );

                          // 高度够就直接展示；高度不够就允许滚动，避免 RenderFlex overflow
                          if (desiredCalendarHeight <= constraints.maxHeight + 0.5) {
                            return calendar;
                          }

                          return SingleChildScrollView(
                            primary: false,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              height: desiredCalendarHeight,
                              child: calendar,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 右侧：当天日程列表
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    DateFormat.yMMMMEEEEd('zh_CN').format(selectedDate),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Expanded(
                  child: eventsAsync.when(
                    data: (events) {
                      if (events.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('暂无日程', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return EventListItem(event: event);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.black87),
            tooltip: '所有日程',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventListScreen()),
              );
            },
          ),
          const Spacer(),
          // Center: Year/Month Selector
          DropdownButton<int>(
            value: _focusedDay.year,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            items: List.generate(10, (index) => 2020 + index).map((year) {
              return DropdownMenuItem(value: year, child: Text('$year年'));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _focusedDay = DateTime(val, _focusedDay.month, _focusedDay.day);
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.grey),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
              });
            },
          ),
          DropdownButton<int>(
            value: _focusedDay.month,
            underline: const SizedBox(),
             style: const TextStyle(fontSize: 16, color: Colors.black87),
            items: List.generate(12, (index) => index + 1).map((month) {
              return DropdownMenuItem(value: month, child: Text('$month月'));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, val, _focusedDay.day);
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
              });
            },
          ),
          const Spacer(),
          // Right: Today Button
          OutlinedButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedDay = now;
              });
              ref.read(selectedDateProvider.notifier).state = now;
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              foregroundColor: Colors.black87,
            ),
            child: const Text('今天'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell(BuildContext context, DateTime day, bool isSelected, {bool isToday = false, bool isOutside = false}) {
    // 1) 农历 & 节日信息
    final solar = Solar.fromDate(day);
    final lunar = solar.getLunar();
    final lunarDay = lunar.getDayInChinese();
    final lunarMonth = lunar.getMonthInChinese();
    
    // 节日/节气优先级处理
    List<String> festivals = lunar.getFestivals();
    // 如需补充公历节日（元旦/劳动节等）可在此扩展；当前 lunar 包已覆盖大部分传统节日
    
    String displayText = '$lunarMonth$lunarDay';
    bool isFestival = false;
    
    // 优先级：节日 > 节气 > 农历日期
    if (festivals.isNotEmpty) {
      displayText = festivals.first;
      isFestival = true;
    } else {
      final jieQi = lunar.getJieQi();
      if (jieQi.isNotEmpty) {
        displayText = jieQi;
        isFestival = true; // 节气也高亮
      } else if (lunar.getDay() == 1) {
        displayText = '$lunarMonth月';
        isFestival = true; // 农历初一显示月份并高亮
      }
    }

    // 2) 法定节假日/调休（“休/班”角标）
    // lunar 1.7.8 的 HolidayUtil.getHoliday 需要 yyyy-MM-dd 格式
    String dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    Holiday? holiday = HolidayUtil.getHoliday(dateStr);
    bool isOffDay = false;
    bool isWorkDay = false;
    
    if (holiday != null) {
      isOffDay = !holiday.isWork();
      isWorkDay = holiday.isWork();
    } else {
        // 无节假日数据时不显示角标（不使用“周末=休”这种简化逻辑）
    }

    // 3) 颜色
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final primaryColor = Theme.of(context).primaryColor;
    
    // 日期文本颜色
    Color dateColor = Colors.black87;
    if (isOutside) dateColor = Colors.grey.shade400;
    else if (isToday) dateColor = Colors.blue;
    // 周末日期红色
    else if (isWeekend) dateColor = Colors.red;

    Color lunarColor = Colors.grey;
    if (isOutside) lunarColor = Colors.grey.shade300;
    else if (isFestival) lunarColor = isWeekend ? Colors.red : primaryColor; // 节日/节气高亮
    
    // 节假日淡红色底
    Color? cellBgColor;
    if (isOffDay && !isOutside) {
        cellBgColor = const Color(0xFFFFF0F0); // 节假日淡红背景
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 主体
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: cellBgColor,
            border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            // 窗口缩放时格子可能变小；用 scaleDown 让内容自适应，避免 RenderFlex overflow
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 公历日
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: dateColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 农历/节日/节气
                  Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 12,
                      color: lunarColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // “今”角标
        if (isToday)
           Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '今',
                style: TextStyle(color: Colors.white, fontSize: 8),
              ),
            ),
          ),

        // “休”角标
        if (isOffDay && !isOutside)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '休',
                style: TextStyle(color: Colors.white, fontSize: 8),
              ),
            ),
          ),

        // “班”角标
        if (isWorkDay && !isOutside)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '班',
                style: TextStyle(color: Colors.white, fontSize: 8),
              ),
            ),
          ),
      ],
    );
  }
}
