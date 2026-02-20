import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/work_entry.dart';
import '../storage/work_storage.dart';

class MonthScreen extends StatefulWidget {
  final int year;
  final int month;
  const MonthScreen({super.key, required this.year, required this.month});

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  final storage = WorkStorage();
  Map<String, WorkEntry> all = {};
  bool loading = true;

  int defaultStart = 7 * 60;
  int defaultEnd = 15 * 60;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    all = await storage.loadAll();
    final (s, e) = await storage.loadDefaultShift();
    setState(() {
      defaultStart = s;
      defaultEnd = e;
      loading = false;
    });
  }

  int _daysInMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final next = DateTime(year, month + 1, 1);
    return next.difference(first).inDays;
  }

  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  DateTime _parseIso(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Future<int?> _pickTimeMinutes(BuildContext context, int initialMinutes) async {
    final initial = TimeOfDay(
      hour: initialMinutes ~/ 60,
      minute: initialMinutes % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return null;
    return picked.hour * 60 + picked.minute;
  }

  String _fmt(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _copyYesterdayToToday() async {
    final now = DateTime.now();
    if (now.year != widget.year || now.month != widget.month) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kopiranje radi unutar trenutnog mjeseca (današnji datum).'),
        ),
      );
      return;
    }

    final todayIso = _iso(now);
    final yesterdayIso = _iso(now.subtract(const Duration(days: 1)));

    final yEntry = all[yesterdayIso];
    if (yEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema unosa za jučer.')),
      );
      return;
    }

    final newEntry = WorkEntry(
      dateIso: todayIso,
      startMinutes: yEntry.startMinutes,
      endMinutes: yEntry.endMinutes,
    );
    await storage.upsert(newEntry);
    all[todayIso] = newEntry;

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kopirano na danas ($todayIso).')),
    );
  }

  Future<void> _setDefaultShiftDialog() async {
    int tempStart = defaultStart;
    int tempEnd = defaultEnd;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default smjena'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Od')),
                TextButton(
                  onPressed: () async {
                    final picked = await _pickTimeMinutes(ctx, tempStart);
                    if (picked == null) return;
                    tempStart = picked;
                    (ctx as Element).markNeedsBuild();
                  },
                  child: Text(_fmt(tempStart)),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('Do')),
                TextButton(
                  onPressed: () async {
                    final picked = await _pickTimeMinutes(ctx, tempEnd);
                    if (picked == null) return;
                    tempEnd = picked;
                    (ctx as Element).markNeedsBuild();
                  },
                  child: Text(_fmt(tempEnd)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Savjet: Ako je Do < Od, tretira se kao smjena preko ponoći.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () async {
              await storage.saveDefaultShift(tempStart, tempEnd);
              setState(() {
                defaultStart = tempStart;
                defaultEnd = tempEnd;
              });
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Spremi'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyDefaultToDay(String iso) async {
    final entry = WorkEntry(
      dateIso: iso,
      startMinutes: defaultStart,
      endMinutes: defaultEnd,
    );
    await storage.upsert(entry);
    all[iso] = entry;
    setState(() {});
  }

  List<WorkEntry> _entriesForThisMonthSorted() {
    final prefix =
        '${widget.year.toString().padLeft(4, '0')}-${widget.month.toString().padLeft(2, '0')}-';
    final entries = all.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => e.value)
        .toList();
    entries.sort((a, b) => a.dateIso.compareTo(b.dateIso));
    return entries;
  }

  Future<Uint8List> _buildMonthPdf() async {
    final doc = pw.Document();
    final monthTitle = DateFormat('MMMM yyyy', 'hr')
        .format(DateTime(widget.year, widget.month));

    final entries = _entriesForThisMonthSorted();
    final totalMinutes = storage.sumMonthMinutes(widget.year, widget.month, all);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text('Radni sati — $monthTitle',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('Ukupno u mjesecu: ${storage.formatHoursMinutes(totalMinutes)}',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Datum')),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Od')),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Do')),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Ukupno')),
                ],
              ),
              ...entries.map((e) {
                final d = _parseIso(e.dateIso);
                final dateLabel =
                    DateFormat('d.M.yyyy (EEE)', 'hr').format(d);
                final dayMinutes = e.durationMinutes();
                return pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(dateLabel)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_fmt(e.startMinutes))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_fmt(e.endMinutes))),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child:
                          pw.Text(storage.formatHoursMinutes(dayMinutes)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _exportPdf() async {
    final data = await _buildMonthPdf();
    await Printing.layoutPdf(onLayout: (_) async => data);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final days = _daysInMonth(widget.year, widget.month);
    final monthTotal = storage.sumMonthMinutes(widget.year, widget.month, all);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy', 'hr')
            .format(DateTime(widget.year, widget.month))),
        actions: [
          IconButton(
            tooltip: 'Kopiraj jučer → danas',
            onPressed: _copyYesterdayToToday,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Default smjena',
            onPressed: _setDefaultShiftDialog,
            icon: const Icon(Icons.schedule),
          ),
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Ukupno u mjesecu: ${storage.formatHoursMinutes(monthTotal)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView.separated(
        itemCount: days,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final date = DateTime(widget.year, widget.month, i + 1);
          final iso = _iso(date);
          final entry = all[iso];

          final start = entry?.startMinutes ?? defaultStart;
          final end = entry?.endMinutes ?? defaultEnd;
          final dayMinutes = entry == null ? 0 : entry.durationMinutes();

          return ListTile(
            title: Text(DateFormat('EEE, d.M.', 'hr').format(date)),
            subtitle: Text(
              entry == null
                  ? 'Nema unosa'
                  : 'Danas: ${storage.formatHoursMinutes(dayMinutes)}',
            ),
            trailing: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Postavi default smjenu za dan',
                  onPressed: () => _applyDefaultToDay(iso),
                  icon: const Icon(Icons.flash_on),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await _pickTimeMinutes(context, start);
                    if (picked == null) return;

                    final newEntry = WorkEntry(
                      dateIso: iso,
                      startMinutes: picked,
                      endMinutes: end,
                    );
                    await storage.upsert(newEntry);
                    all[iso] = newEntry;
                    setState(() {});
                  },
                  child: Text('Od ${_fmt(start)}'),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await _pickTimeMinutes(context, end);
                    if (picked == null) return;

                    final newEntry = WorkEntry(
                      dateIso: iso,
                      startMinutes: start,
                      endMinutes: picked,
                    );
                    await storage.upsert(newEntry);
                    all[iso] = newEntry;
                    setState(() {});
                  },
                  child: Text('Do ${_fmt(end)}'),
                ),
                IconButton(
                  tooltip: 'Obriši dan',
                  onPressed: entry == null
                      ? null
                      : () async {
                          await storage.remove(iso);
                          all.remove(iso);
                          setState(() {});
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
