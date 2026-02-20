import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/year_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('hr', null);
  runApp(const WorkHoursApp());
}

class WorkHoursApp extends StatelessWidget {
  const WorkHoursApp({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Radni sati',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: YearScreen(year: now.year),
    );
  }
}
