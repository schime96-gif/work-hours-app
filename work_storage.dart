import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_entry.dart';

class WorkStorage {
  static const _keyEntries = 'work_entries_v1';
  static const _keyDefaultStart = 'default_start_minutes_v1';
  static const _keyDefaultEnd = 'default_end_minutes_v1';

  Future<Map<String, WorkEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyEntries);
    if (raw == null || raw.trim().isEmpty) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((dateIso, value) {
      return MapEntry(
        dateIso,
        WorkEntry.fromJson(value as Map<String, dynamic>),
      );
    });
  }

  Future<void> upsert(WorkEntry entry) async {
    final all = await loadAll();
    all[entry.dateIso] = entry;
    await _saveAll(all);
  }

  Future<void> remove(String dateIso) async {
    final all = await loadAll();
    all.remove(dateIso);
    await _saveAll(all);
  }

  Future<void> _saveAll(Map<String, WorkEntry> all) async {
    final prefs = await SharedPreferences.getInstance();
    final map = all.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_keyEntries, jsonEncode(map));
  }

  int sumMonthMinutes(int year, int month, Map<String, WorkEntry> all) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    int total = 0;
    for (final e in all.entries) {
      if (e.key.startsWith(prefix)) total += e.value.durationMinutes();
    }
    return total;
  }

  int sumYearMinutes(int year, Map<String, WorkEntry> all) {
    final prefix = '${year.toString().padLeft(4, '0')}-';
    int total = 0;
    for (final e in all.entries) {
      if (e.key.startsWith(prefix)) total += e.value.durationMinutes();
    }
    return total;
  }

  String formatHoursMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString()}:${m.toString().padLeft(2, '0')} h';
  }

  Future<(int start, int end)> loadDefaultShift() async {
    final prefs = await SharedPreferences.getInstance();
    final start = prefs.getInt(_keyDefaultStart) ?? 7 * 60; // 07:00
    final end = prefs.getInt(_keyDefaultEnd) ?? 15 * 60; // 15:00
    return (start, end);
  }

  Future<void> saveDefaultShift(int startMinutes, int endMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultStart, startMinutes);
    await prefs.setInt(_keyDefaultEnd, endMinutes);
  }
}
