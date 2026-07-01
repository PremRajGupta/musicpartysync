import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/client_screen.dart';
import 'services/websocket_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketService()),
      ],
      child: const MusicPartySyncApp(),
    ),
  );
}

class MusicPartySyncApp extends StatelessWidget {
  const MusicPartySyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Extract room parameter from URL (e.g. ?room=WCS5D5)
    String? roomParam = Uri.base.queryParameters['room'];

    return MaterialApp(
      title: 'Music Party Sync',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark blue background
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF007F),
        ),
      ),
      home: roomParam != null && roomParam.isNotEmpty 
          ? ClientScreen(initialRoom: roomParam) 
          : const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
