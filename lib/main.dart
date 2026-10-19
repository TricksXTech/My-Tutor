import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'data/services/storage_service.dart';
import 'providers/subject_provider.dart';
import 'providers/chapter_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/tutor_settings_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure dark system navigation and status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize offline storage service
  final storageService = await StorageService.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SubjectProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => ChapterProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => TutorSettingsProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(storageService),
        ),
      ],
      child: const MyTutorApp(),
    ),
  );
}

class MyTutorApp extends StatelessWidget {
  const MyTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Tutor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
