import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'router.dart';

class LunexApp extends StatelessWidget {
  const LunexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lunex',
      theme: AppTheme.light(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
      debugShowCheckedModeBanner: false,
    );
  }
}
