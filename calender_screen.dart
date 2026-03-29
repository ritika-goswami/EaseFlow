import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easeflow_app/user_data.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int currentMonthIndex = DateTime.now().month - 1;
  int currentYear = 2026;
  final List<String> months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  // Logic storage
  List<Map<String, DateTime>> periodHistory = [];
  int userPeriodDuration = 6;
  int totalCycleLength = 28;
  DateTime? lastLoggedDate;

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    String rawCycle = prefs.getString('cycleLength') ?? "6 days";
    String? historyJson = prefs.getString('period_history_list');
    
    setState(() {
      userPeriodDuration = int.parse(rawCycle.replaceAll(RegExp(r'[^0-9]'), ''));
      
      if (historyJson != null) {
        Iterable l = json.decode(historyJson);
        periodHistory = l.map((item) => {
          "start": DateTime.parse(item['start']),
          "end": DateTime.parse(item['end']),
        }).toList();
        
        // Sort to ensure the latest log is always the primary anchor
        if (periodHistory.isNotEmpty) {
          periodHistory.sort((a, b) => b['start']!.compareTo(a['start']!));
          lastLoggedDate = periodHistory.first['start'];
        }
      }
    });
  }

  Future<void> _savePeriodHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> export = periodHistory.map((item) => {
      "start": item['start']!.toIso8601String(),
      "end": item['end']!.toIso8601String(),
    }).toList();
    await prefs.setString('period_history_list', json.encode(export));
  }

  int get _calculatedDay {
    if (lastLoggedDate == null) return 1;
    DateTime now = DateTime.now();
    // Calculate difference based on the most recent manual log
    int daysSinceLog = now.difference(lastLoggedDate!).inDays;
    
    // If we are past a full cycle, we predict based on the last log
    return (daysSinceLog % totalCycleLength) + 1;
  }

  String get _phaseName {
    int day = _calculatedDay;
    if (day <= userPeriodDuration) return "period\nphase";
    if (day <= 13) return "follicular\nphase";
    if (day <= 16) return "fertile\nwindow";
    return "luteal\nphase";
  }

  Color get _currentPhaseColor {
    int day = _calculatedDay;
    if (day <= userPeriodDuration) return const Color(0xFFFF6B6B);
    if (day <= 13) return const Color(0xFF7CFF79);
    if (day <= 16) return const Color(0xFF50C5F9);
    return const Color(0xFFD4E157);
  }

  bool _isDateInPeriod(DateTime date) {
    for (var event in periodHistory) {
      if ((date.isAfter(event['start']!) || DateUtils.isSameDay(date, event['start']!)) &&
          (date.isBefore(event['end']!) || DateUtils.isSameDay(date, event['end']!))) {
        return true;
      }
    }
    return false;
  }

  void _showLogPeriodPopup() {
    TextEditingController dateController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop, color: Color(0xFFFF6B6B)),
                SizedBox(width: 10),
                Text("Start date for this month?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: dateController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Enter day (e.g. 27)",
                filled: true,
                fillColor: const Color(0xFFFDE4E4).withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE79AA2), shape: const StadiumBorder()),
              onPressed: () {
                if (dateController.text.isNotEmpty) {
                  int day = int.parse(dateController.text);
                  DateTime start = DateTime(currentYear, currentMonthIndex + 1, day);
                  DateTime end = start.add(Duration(days: userPeriodDuration - 1));
                  
                  setState(() {
                    // CRITICAL FIX: Remove any existing history for the same month/year to avoid double-showing
                    periodHistory.removeWhere((element) => 
                      element['start']!.month == start.month && 
                      element['start']!.year == start.year
                    );

                    periodHistory.add({"start": start, "end": end});
                    // Re-sort to make sure the latest date is the anchor
                    periodHistory.sort((a, b) => b['start']!.compareTo(a['start']!));
                    lastLoggedDate = periodHistory.first['start'];
                  });
                  _savePeriodHistory();
                  Navigator.pop(context);
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildFigmaHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildPhaseCard(),
                    const SizedBox(height: 25),
                    _buildMonthSelector(),
                    _buildCalendarGrid(),
                    const SizedBox(height: 25),
                    _buildActionRow(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFigmaHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 30),
      decoration: const BoxDecoration(
        color: Color(0xFFFDE4E4),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<String>(
                future: UserData.getUserName(),
                builder: (context, snapshot) {
                  String fName = snapshot.data?.split(' ')[0] ?? "User";
                  return Text("Hi, $fName 👋", 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE79AA2), fontFamily: 'Serif'));
                }
              ),
              const Text("Your Cycle Track", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Serif', color: Colors.black)),
            ],
          ),
          const CircleAvatar(backgroundColor: Colors.white, radius: 22, child: Icon(Icons.person, color: Colors.black, size: 24)),
        ],
      ),
    );
  }

  Widget _buildPhaseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("today is day", style: TextStyle(color: Colors.grey, fontSize: 16)),
                Text("$_calculatedDay", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              ]),
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(110, 110),
                    painter: CyclePainter(currentDay: _calculatedDay, periodDuration: userPeriodDuration),
                  ),
                  Text(_phaseName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 15, runSpacing: 10, alignment: WrapAlignment.center,
            children: [
              _LegendItem(Color(0xFF7CFF79), "follicular phase"),
              _LegendItem(Color(0xFF50C5F9), "fertile window"),
              _LegendItem(Color(0xFFFF6B6B), "period phase"),
              _LegendItem(Color(0xFFD4E157), "luteal phase"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
            setState(() {
              if (currentMonthIndex == 0) {
                currentMonthIndex = 11;
                currentYear--;
              } else {
                currentMonthIndex--;
              }
            });
          }),
          Text("${months[currentMonthIndex]}, $currentYear", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
            setState(() {
              if (currentMonthIndex == 11) {
                currentMonthIndex = 0;
                currentYear++;
              } else {
                currentMonthIndex++;
              }
            });
          }),
        ]),
        _buildEditButton(),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    DateTime firstDayOfMonth = DateTime(currentYear, currentMonthIndex + 1, 1);
    int precedingDays = firstDayOfMonth.weekday - 1; 
    DateTime startDate = firstDayOfMonth.subtract(Duration(days: precedingDays));
    
    List<DateTime> calendarDays = List.generate(35, (i) => startDate.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFFDE4E4).withOpacity(0.3), borderRadius: BorderRadius.circular(30)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                .map((d) => Text(d, style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 12))).toList(),
          ),
          const SizedBox(height: 15),
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: calendarDays.sublist(i * 7, (i + 1) * 7).map((date) {
                  bool isCurrentMonth = date.month == currentMonthIndex + 1;
                  bool isToday = DateUtils.isSameDay(date, DateTime.now());
                  bool isPeriod = _isDateInPeriod(date);

                  return Container(
                    width: 35, height: 35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isToday ? Border.all(color: _currentPhaseColor, width: 2.5) : null,
                      color: isPeriod ? const Color(0xFFFF6B6B).withOpacity(0.2) : null,
                    ),
                    child: isPeriod 
                      ? const Icon(Icons.water_drop, color: Color(0xFFFF6B6B), size: 18)
                      : Text(date.day.toString(), style: TextStyle(color: isCurrentMonth ? Colors.black : Colors.grey, fontSize: 13)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: _showLogPeriodPopup,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFDE4E4).withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [Text("log period ", style: TextStyle(fontWeight: FontWeight.bold)), Icon(Icons.add, size: 16)]),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFDE4E4), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE79AA2))),
          child: Row(
            children: [
              const Icon(Icons.water_drop, color: Color(0xFFFF6B6B), size: 18),
              const SizedBox(width: 8),
              Text("periods ($userPeriodDuration days)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2025),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFFE79AA2))), child: child!);
          }
        );
        if (picked != null) {
          setState(() {
            // FIX: Remove entries that overlap with the new manual range
            periodHistory.removeWhere((element) => 
              (picked.start.isBefore(element['end']!) && picked.end.isAfter(element['start']!))
            );

            periodHistory.add({"start": picked.start, "end": picked.end});
            periodHistory.sort((a, b) => b['start']!.compareTo(a['start']!));
            lastLoggedDate = periodHistory.first['start'];
          });
          _savePeriodHistory();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFDE4E4), borderRadius: BorderRadius.circular(20)),
        child: const Row(children: [Icon(Icons.edit, size: 14), SizedBox(width: 5), Text("Edit Dates", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem(this.color, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }
}

class CyclePainter extends CustomPainter {
  final int currentDay;
  final int periodDuration;
  CyclePainter({required this.currentDay, required this.periodDuration});

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 14;
    Rect rect = Offset.zero & size;
    Paint paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = strokeWidth;
    double totalCycle = 28.0;
    double startAngle = -pi / 2;

    double pA = (periodDuration / totalCycle) * 2 * pi;
    canvas.drawArc(rect, startAngle, pA, false, paint..color = const Color(0xFFFF6B6B));
    double fA = (7 / totalCycle) * 2 * pi;
    canvas.drawArc(rect, startAngle + pA, fA, false, paint..color = const Color(0xFF7CFF79));
    double ferA = (5 / totalCycle) * 2 * pi;
    canvas.drawArc(rect, startAngle + pA + fA, ferA, false, paint..color = const Color(0xFF50C5F9));
    double lA = 2 * pi - (pA + fA + ferA);
    canvas.drawArc(rect, startAngle + pA + fA + ferA, lA, false, paint..color = const Color(0xFFD4E157));
    
    double trackerAngle = startAngle + (currentDay / totalCycle) * 2 * pi;
    Offset dotPos = Offset(size.width/2 + (size.width/2) * cos(trackerAngle), size.height/2 + (size.height/2) * sin(trackerAngle));
    canvas.drawCircle(dotPos, 8, Paint()..color = Colors.white);
    canvas.drawCircle(dotPos, 5, Paint()..color = Colors.black);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
