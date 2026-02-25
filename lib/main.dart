import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? false;
  final savedLang = prefs.getString('language') ?? 'en';
  final soundOn = prefs.getBool('soundOn') ?? true;
  final vibrationOn = prefs.getBool('vibrationOn') ?? true;

  runApp(LingoLensApp(
    initialDarkMode: isDark,
    initialLanguage: savedLang,
    initialSound: soundOn,
    initialVibration: vibrationOn,
  ));
}

class LingoLensApp extends StatefulWidget {
  final bool initialDarkMode;
  final String initialLanguage;
  final bool initialSound;
  final bool initialVibration;

  const LingoLensApp({
    super.key,
    this.initialDarkMode = false,
    this.initialLanguage = "en",
    this.initialSound = true,
    this.initialVibration = true,
  });

  @override
  State<LingoLensApp> createState() => _LingoLensAppState();
}

class _LingoLensAppState extends State<LingoLensApp> {
  late ThemeMode _themeMode;
  late Locale _locale;
  late bool _soundOn;
  late bool _vibrationOn;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;
    _locale = Locale(widget.initialLanguage);
    _soundOn = widget.initialSound;
    _vibrationOn = widget.initialVibration;
  }

  void toggleTheme(bool isDark) async {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
  }

  void changeLanguage(String langCode) async {
    setState(() => _locale = Locale(langCode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
  }

  void toggleSound(bool value) async {
    setState(() => _soundOn = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundOn', value);
  }

  void toggleVibration(bool value) async {
    setState(() => _vibrationOn = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationOn', value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LingoLens AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [
        Locale('en'), Locale('fr'), Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeScreen(
        toggleTheme: toggleTheme,
        changeLanguage: changeLanguage,
        soundOn: _soundOn,
        vibrationOn: _vibrationOn,
        toggleSound: toggleSound,
        toggleVibration: toggleVibration,
        isDarkMode: _themeMode == ThemeMode.dark,
        currentLanguage: _locale.languageCode,
      ),
    );
  }
}