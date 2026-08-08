import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('fa');

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void toggleLanguage() {
    setState(() {
      _locale = _locale.languageCode == 'fa'
          ? const Locale('en')
          : const Locale('fa');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'v2source',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      locale: _locale,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: HomePage(
        onToggleTheme: toggleTheme,
        onToggleLanguage: toggleLanguage,
        isDark: _themeMode == ThemeMode.dark,
        isFa: _locale.languageCode == 'fa',
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLanguage;
  final bool isDark;
  final bool isFa;

  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.onToggleLanguage,
    required this.isDark,
    required this.isFa,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String subUrl =
      'https://raw.githubusercontent.com/v2rayCrow/Sub-Link-Output/main/all.txt#v2sourceALL';

  late FlutterV2ray v2ray;
  bool isConnected = false;
  bool isLoading = false;

  List<Map<String, String>> configList = [];
  String? selectedConfig;
  String lastUpdateText = '';
  String telegramUrl = 'https://t.me/V2Source';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          isConnected = status.state == 'CONNECTED';
        });
      },
    );
    v2ray.initializeV2Ray();
    fetchSubscription();

    _timer = Timer.periodic(const Duration(hours: 6), (timer) {
      fetchSubscription();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String decodeRemark(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.fragment.isNotEmpty) {
        return Uri.decodeComponent(uri.fragment);
      }
    } catch (_) {}
    return widget.isFa ? 'سرور بدون نام' : 'Unnamed Server';
  }

  Future<void> fetchSubscription() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(subUrl));
      if (response.statusCode == 200) {
        String content = response.body.trim();

        try {
          content = utf8.decode(base64.decode(content));
        } catch (_) {}

        List<String> lines = content
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          // کانفیگ اول: تاریخ آخرین آپدیت
          lastUpdateText = decodeRemark(lines[0]);
        }

        List<Map<String, String>> parsedConfigs = [];
        // شروع از اندیس ۲ برای حذف دو کانفیگ ثابت اول
        for (int i = 2; i < lines.length; i++) {
          final raw = lines[i];
          final name = decodeRemark(raw);
          parsedConfigs.add({
            'name': name,
            'config': raw,
          });
        }

        setState(() {
          configList = parsedConfigs;
          if (configList.isNotEmpty) {
            selectedConfig = configList.first['config'];
          }
        });
      }
    } catch (_) {
    } finally {
      setState(() => isLoading = false);
    }
  }

  void toggleConnect() async {
    if (selectedConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isFa
                ? 'لطفا ابتدا یک کانفیگ انتخاب کنید'
                : 'Please select a config first',
          ),
        ),
      );
      return;
    }

    if (isConnected) {
      await v2ray.stopV2Ray();
    } else {
      if (await v2ray.requestPermission()) {
        final current = configList.firstWhere(
          (element) => element['config'] == selectedConfig,
          orElse: () => {'name': 'v2source', 'config': selectedConfig!},
        );
        await v2ray.startV2Ray(
          remark: current['name']!,
          config: selectedConfig!,
        );
      }
    }
  }

  Future<void> _openTelegram() async {
    final Uri url = Uri.parse(telegramUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Ignore error if cannot launch
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFa = widget.isFa;

    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('v2source'),
          actions: [
            IconButton(
              icon: Icon(
                widget.isDark ? Icons.wb_sunny : Icons.nightlight_round,
              ),
              onPressed: widget.onToggleTheme,
            ),
            TextButton(
              onPressed: widget.onToggleLanguage,
              child: Text(
                isFa ? 'EN' : 'FA',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: fetchSubscription,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (isLoading) const LinearProgressIndicator(),

              // نمایش آخرین آپدیت و دکمه کانال تلگرام
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastUpdateText.isEmpty
                              ? (isFa
                                  ? 'در حال دریافت اطلاعات...'
                                  : 'Fetching info...')
                              : lastUpdateText,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openTelegram,
                        icon: const Icon(Icons.send, size: 16),
                        label: Text(isFa ? 'کانال تلگرام' : 'Channel'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // دکمه بزرگ اتصال
              ElevatedButton(
                onPressed: toggleConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : Colors.green,
                  minimumSize: const Size(130, 130),
                  shape: const CircleBorder(),
                ),
                child: Text(
                  isConnected
                      ? (isFa ? 'قطع اتصال' : 'STOP')
                      : (isFa ? 'اتصال' : 'START'),
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Align(
                alignment: isFa ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  isFa ? 'لیست سرورها:' : 'Server List:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  itemCount: configList.length,
                  itemBuilder: (context, index) {
                    final item = configList[index];
                    final isSelected = item['config'] == selectedConfig;
                    return Card(
                      color: isSelected
                          ? Colors.blue.withOpacity(0.2)
                          : null,
                      child: ListTile(
                        leading: const Icon(
                          Icons.vpn_key,
                          color: Colors.blueAccent,
                        ),
                        title: Text(
                          item['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            selectedConfig = item['config'];
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
