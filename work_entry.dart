class WorkEntry {
  final String dateIso; // yyyy-MM-dd
  final int startMinutes; // minutes since midnight
  final int endMinutes;   // minutes since midnight

  WorkEntry({
    required this.dateIso,
    required this.startMinutes,
    required this.endMinutes,
  });

  Map<String, dynamic> toJson() => {
        'dateIso': dateIso,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  static WorkEntry fromJson(Map<String, dynamic> j) => WorkEntry(
        dateIso: j['dateIso'] as String,
        startMinutes: j['startMinutes'] as int,
        endMinutes: j['endMinutes'] as int,
      );

  /// Duration in minutes; supports overnight shifts (end < start).
  int durationMinutes() {
    int start = startMinutes;
    int end = endMinutes;
    if (end < start) end += 24 * 60; // crosses midnight
    final diff = end - start;
    return diff < 0 ? 0 : diff;
  }
}
