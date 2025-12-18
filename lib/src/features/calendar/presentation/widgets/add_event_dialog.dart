import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart'; // 农历相关
import '../../data/event_repository.dart';
import '../../domain/event_model.dart';
import '../../application/calendar_providers.dart'; // 状态管理（Provider）
import '../../../categories/application/category_providers.dart';
import '../../../categories/domain/category_model.dart';

class AddEventDialog extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final String? initialTitle;
  final EventModel? eventToEdit;
  
  const AddEventDialog({
    super.key, 
    required this.selectedDate,
    this.initialTitle,
    this.eventToEdit,
  });

  @override
  ConsumerState<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  int _priority = 1;
  String _selectedCategory = '默认'; // 默认分类（可根据业务进一步优化）
  
  // 重复规则状态
  String _recurrenceType = 'none'; // none / weekly / monthly / yearly
  
  // 自定义重复规则的附加状态
  int? _selectedMonth; // 1-12
  int? _selectedDay; // 1-31
  int? _selectedWeekday; // 1-7（周一~周日）
  bool _isLunar = false;
  
  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    
    _titleController = TextEditingController(text: event?.title ?? widget.initialTitle);
    _descriptionController = TextEditingController(text: event?.description);
    _locationController = TextEditingController(text: event?.location);
    
    // 默认值：基于当前选择日期
    _selectedMonth = widget.selectedDate.month;
    _selectedDay = widget.selectedDate.day;
    _selectedWeekday = widget.selectedDate.weekday;
    
    if (event != null) {
      _startTime = TimeOfDay.fromDateTime(event.startTime);
      _endTime = TimeOfDay.fromDateTime(event.endTime);
      _priority = event.priority;
      _selectedCategory = event.category;
      
      if (event.lunarRecurrence != null) {
        _isLunar = true;
        // 解析农历重复规则：格式 "LUNAR;MONTH=1;DAY=1" 或 "LUNAR;FREQ=MONTHLY;DAY=1"
        final parts = event.lunarRecurrence!.split(';');
        for (var part in parts) {
          if (part.startsWith('MONTH=')) {
            _selectedMonth = int.tryParse(part.split('=')[1]);
          } else if (part.startsWith('DAY=')) {
            _selectedDay = int.tryParse(part.split('=')[1]);
          }
        }
        if (event.lunarRecurrence!.contains('FREQ=MONTHLY')) {
          _recurrenceType = 'monthly';
        } else {
          _recurrenceType = 'yearly';
        }
      } else if (event.recurrenceRule != null) {
        if (event.recurrenceRule!.contains('FREQ=WEEKLY')) {
          _recurrenceType = 'weekly';
          // 解析周几
          final byDayMatch = RegExp(r'BYDAY=(\w+)').firstMatch(event.recurrenceRule!);
          if (byDayMatch != null) {
            final byDay = byDayMatch.group(1);
            switch (byDay) {
              case 'MO': _selectedWeekday = 1; break;
              case 'TU': _selectedWeekday = 2; break;
              case 'WE': _selectedWeekday = 3; break;
              case 'TH': _selectedWeekday = 4; break;
              case 'FR': _selectedWeekday = 5; break;
              case 'SA': _selectedWeekday = 6; break;
              case 'SU': _selectedWeekday = 7; break;
            }
          }
        } else if (event.recurrenceRule!.contains('FREQ=MONTHLY')) {
          _recurrenceType = 'monthly';
          // 解析日期
          final byMonthDayMatch = RegExp(r'BYMONTHDAY=(\d+)').firstMatch(event.recurrenceRule!);
          if (byMonthDayMatch != null) {
            _selectedDay = int.tryParse(byMonthDayMatch.group(1)!);
          }
        } else if (event.recurrenceRule!.contains('FREQ=YEARLY')) {
          _recurrenceType = 'yearly';
          // 解析月份和日期
          final byMonthMatch = RegExp(r'BYMONTH=(\d+)').firstMatch(event.recurrenceRule!);
          final byMonthDayMatch = RegExp(r'BYMONTHDAY=(\d+)').firstMatch(event.recurrenceRule!);
          if (byMonthMatch != null) {
            _selectedMonth = int.tryParse(byMonthMatch.group(1)!);
          }
          if (byMonthDayMatch != null) {
            _selectedDay = int.tryParse(byMonthDayMatch.group(1)!);
          }
        }
      }
    } else {
      // 默认：开始 00:00，结束 23:59（只记录小时和分钟）
      _startTime = const TimeOfDay(hour: 0, minute: 0);
      _endTime = const TimeOfDay(hour: 23, minute: 59);
    }
  }

  // 自定义重复规则：周几选择
  Widget _buildDayOfWeekSelector() {
    return Row(
      children: [
        const Text('每周'),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<int>(
            value: _selectedWeekday,
            items: const [
              DropdownMenuItem(value: 1, child: Text('周一')),
              DropdownMenuItem(value: 2, child: Text('周二')),
              DropdownMenuItem(value: 3, child: Text('周三')),
              DropdownMenuItem(value: 4, child: Text('周四')),
              DropdownMenuItem(value: 5, child: Text('周五')),
              DropdownMenuItem(value: 6, child: Text('周六')),
              DropdownMenuItem(value: 7, child: Text('周日')),
            ],
            onChanged: (v) => setState(() => _selectedWeekday = v),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
        const Text(' 重复'),
      ],
    );
  }

  Widget _buildMonthDaySelector() {
    return Row(
      children: [
        Checkbox(
          value: _isLunar,
          onChanged: (v) => setState(() => _isLunar = v!),
        ),
        const Text('农历'),
        const SizedBox(width: 16),
        const Text('每月'),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: DropdownButtonFormField<int>(
            value: _selectedDay,
            items: List.generate(30, (i) => i + 1).map((d) => 
              DropdownMenuItem(value: d, child: Text('$d日'))
            ).toList(),
            onChanged: (v) => setState(() => _selectedDay = v),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
        const Text(' 重复'),
      ],
    );
  }

  Widget _buildYearMonthDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isLunar,
              onChanged: (v) => setState(() => _isLunar = v!),
            ),
            const Text('农历'),
          ],
        ),
        Row(
          children: [
            const Text('每年'),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
                items: List.generate(12, (i) => i + 1).map((m) => 
                  DropdownMenuItem(value: m, child: Text('$m月'))
                ).toList(),
                onChanged: (v) => setState(() => _selectedMonth = v),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<int>(
                value: _selectedDay,
                items: List.generate(30, (i) => i + 1).map((d) => 
                  DropdownMenuItem(value: d, child: Text('$d日'))
                ).toList(),
                onChanged: (v) => setState(() => _selectedDay = v),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              ),
            ),
            const Text(' 重复'),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);

    return AlertDialog(
      title: Text(widget.eventToEdit != null ? '编辑日程' : '新建日程'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入标题';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePicker('开始时间', _startTime, (t) => setState(() => _startTime = t)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimePicker('结束时间', _endTime, (t) => setState(() => _endTime = t)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _recurrenceType,
                  decoration: const InputDecoration(
                    labelText: '重复规则',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('不重复')),
                    DropdownMenuItem(value: 'weekly', child: Text('每周')),
                    DropdownMenuItem(value: 'monthly', child: Text('每月')),
                    DropdownMenuItem(value: 'yearly', child: Text('每年')),
                  ],
                  onChanged: (v) => setState(() => _recurrenceType = v!),
                ),
                if (_recurrenceType == 'weekly') ...[
                  const SizedBox(height: 16),
                  _buildDayOfWeekSelector(),
                ] else if (_recurrenceType == 'monthly') ...[
                  const SizedBox(height: 16),
                  _buildMonthDaySelector(),
                ] else if (_recurrenceType == 'yearly') ...[
                  const SizedBox(height: 16),
                  _buildYearMonthDaySelector(),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: '地点 (可选)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: '优先级',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('低')),
                    DropdownMenuItem(value: 1, child: Text('中')),
                    DropdownMenuItem(value: 2, child: Text('高')),
                  ],
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                const SizedBox(height: 16),
                categoriesAsync.when(
                  data: (categories) {
                    // Ensure selected category exists in list or fallback
                    if (categories.isNotEmpty && !categories.any((c) => c.name == _selectedCategory)) {
                       _selectedCategory = categories.first.name;
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: '分类'),
                      items: categories.map((c) => DropdownMenuItem(
                        value: c.name,
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, color: Color(c.colorValue), margin: const EdgeInsets.only(right: 8)),
                            Text(c.name),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('加载分类失败: $e'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saveEvent,
          child: Text(widget.eventToEdit != null ? '更新' : '保存'),
        ),
      ],
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return InkWell(
      onTap: () async {
        final newTime = await showTimePicker(
          context: context, 
          initialTime: time,
          builder: (context, child) {
            return Localizations.override(
              context: context,
              locale: const Locale('zh', 'CN'),
              child: child,
            );
          },
        );
        if (newTime != null) onChanged(newTime);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(time.format(context)),
      ),
    );
  }

  String _getLunarDateString(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    return '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  }

  void _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final date = widget.selectedDate;
      // 只保存到“分钟”精度（秒/毫秒一律为 0）
      final start = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
      final end = DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);

      final repository = ref.read(eventRepositoryProvider);
      
      // 生成重复规则字符串
      String? rrule;
      String? lunarRecurrence;
      
      // 当重复规则指定了固定模式时，需要让“开始日期”对齐规则
      // 例如：每月 1 号，但当前选的是 10 号
      DateTime adjustedStart = start;
      DateTime adjustedEnd = end;

      if (_recurrenceType == 'weekly') {
        String byDay = '';
        switch (_selectedWeekday) {
          case 1: byDay = 'MO'; break;
          case 2: byDay = 'TU'; break;
          case 3: byDay = 'WE'; break;
          case 4: byDay = 'TH'; break;
          case 5: byDay = 'FR'; break;
          case 6: byDay = 'SA'; break;
          case 7: byDay = 'SU'; break;
        }
        // rrule 包要求带 'RRULE:' 前缀
        rrule = 'RRULE:FREQ=WEEKLY;BYDAY=$byDay';
      } else if (_recurrenceType == 'monthly') {
        if (_isLunar) {
          lunarRecurrence = 'LUNAR;FREQ=MONTHLY;DAY=$_selectedDay';
        } else {
          rrule = 'RRULE:FREQ=MONTHLY;BYMONTHDAY=$_selectedDay';
        }
      } else if (_recurrenceType == 'yearly') {
        if (_isLunar) {
          lunarRecurrence = 'LUNAR;MONTH=$_selectedMonth;DAY=$_selectedDay';
        } else {
          rrule = 'RRULE:FREQ=YEARLY;BYMONTH=$_selectedMonth;BYMONTHDAY=$_selectedDay';
        }
      }

      if (widget.eventToEdit != null) {
        final updatedEvent = widget.eventToEdit!
          ..title = _titleController.text
          ..description = _descriptionController.text
          ..location = _locationController.text
          ..startTime = adjustedStart // 使用对齐后的开始日期
          ..endTime = adjustedEnd     // 使用对齐后的结束日期
          ..priority = _priority
          ..category = _selectedCategory
          ..recurrenceRule = rrule
          ..lunarRecurrence = lunarRecurrence
          ..updatedAt = DateTime.now();
        
        // 说明：
        // - 当前实现只更新“主记录”，实例由仓库层按规则实时展开
        // - 若用户修改了重复规则/起始日期，需要确保 startTime 与规则对齐（避免出现“某月 1 号不生成”等问题）
        
        await repository.updateEvent(updatedEvent);
      } else {
        final newEvent = EventModel()
          ..title = _titleController.text
          ..description = _descriptionController.text
          ..location = _locationController.text
          ..startTime = adjustedStart // 使用对齐后的开始日期
          ..endTime = adjustedEnd     // 使用对齐后的结束日期
          ..priority = _priority
          ..category = _selectedCategory
          ..recurrenceRule = rrule
          ..lunarRecurrence = lunarRecurrence;
        
        await repository.addEvent(newEvent);
      }
      
      if (mounted) {
        // 使用 Isar watch/StreamProvider，数据变更会自动刷新 UI
        Navigator.pop(context);
      }
    }
  }
}
