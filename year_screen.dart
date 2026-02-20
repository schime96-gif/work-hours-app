import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../storage/work_storage.dart';
import 'month_screen.dart';

class YearScreen extends StatefulWidget {
  final int year;
  const YearScreen({super.key, required this.year});

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  final storage = WorkStorage();
  bool loading = true;

  Map<int, int> monthTotals = {};
  int yearTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await storage.loadAll();
    final Map<int, int> monthMinutes = {};
    for (int m = 1; m <= 12; m++) {
      monthMinutes[m] = storage.sumMonthMinutes(widget.year, m, all);
    }
    final total = storage.sumYearMinutes(widget.year, all);

    setState(() {
      monthTotals = monthMinutes;
      yearTotal = total;
      loading = false;
    });
  }

  String _monthName(int month) =>
      DateFormat('MMMM', 'hr').format(DateTime(2026, month, 1));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Godina ${widget.year}'),
        actions: [
          IconButton(
            tooltip: 'Osvježi',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Ukupno u godini: ${storage.formatHoursMinutes(yearTotal)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            final minutes = monthTotals[month] ?? 0;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MonthScreen(year: widget.year, month: month),
                  ),
                );
                await _load();
              },
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _monthName(month),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ukupno: ${storage.formatHoursMinutes(minutes)}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
