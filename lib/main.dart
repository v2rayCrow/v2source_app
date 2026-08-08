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
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void toggleLanguage() {
    setState(() {
      _locale = _locale.languageCode == 'fa' ? const Locale('en') : const Locale('fa');
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

class ConfigModel {
  final String rawConfig;
  final String name;
  final String emoji;
  int delay;

  ConfigModel({
    required this.rawConfig,
    required this.name,
    required this.emoji,
    this.delay = -1,
  });
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
  bool isPinging = false;

  List<ConfigModel> configList = [];
  String? selectedConfigRaw;
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

        if (status.state == 'ERROR') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا: ${status.message ?? "اتصال ناموفق"}')),
          );
        }
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

  String extractEmoji(String text) {
    final RegExp emojiRegex = RegExp(
      r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );
    final matches = emojiRegex.allMatches(text);
    if (matches.isNotEmpty) {
      return matches.map((m) => m.group(0)).join();
    }
    return '🌐';
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
          lastUpdateText = decodeRemark(lines[0]);
        }

        List<ConfigModel> parsedConfigs = [];
        for (int i = 2; i < lines.length; i++) {  // معمولاً خط اول و دوم هدر هست
          final raw = lines[i];
          final fullName = decodeRemark(raw);
          final emoji = extractEmoji(fullName);

          parsedConfigs.add(ConfigModel(
            rawConfig: raw,
            name: fullName,
            emoji: emoji,
          ));
        }

        setState(() {
          configList = parsedConfigs;
          if (configList.isNotEmpty && selectedConfigRaw == null) {
            selectedConfigRaw = configList.first.rawConfig;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isFa ? 'خطا در دریافت لیست' : 'Error fetching list')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // پینگ واقعی
  Future<void> testPingAndSort() async {
    if (configList.isEmpty || isPinging) return;

    setState(() => isPinging = true);

    for (var item in configList) {
      try {
        final delay = await v2ray.getServerDelay(config: item.rawConfig);
        item.delay = delay > 0 ? delay : -1;
      } catch (_) {
        item.delay = -1;
      }
    }

    configList.sort((a, b) {
      if (a.delay <= 0) return 1;
      if (b.delay <= 0) return -1;
      return a.delay.compareTo(b.delay);
    });

    setState(() => isPinging = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isFa
              ? 'تست پینگ انجام شد و لیست مرتب گردید'
              : 'Ping test completed & list sorted',
        ),
      ),
    );
  }

  // دکمه اتصال بهبود یافته
  void toggleConnect() async {
    if (selectedConfigRaw == null) {
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
      return;
    }

    try {
      final permission = await v2ray.requestPermission();
      if (!permission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('دسترسی VPN رد شد')),
        );
        return;
      }

      final current = configList.firstWhere(
        (element) => element.rawConfig == selectedConfigRaw,
        orElse: () => ConfigModel(
          rawConfig: selectedConfigRaw!,
          name: 'v2source',
          emoji: '🌐',
        ),
      );

      await v2ray.startV2Ray(
        remark: current.name,
        config: selectedConfigRaw!,
        proxyOnly: false, // VPN Mode
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در شروع اتصال: $e')),
      );
    }
  }

  Future<void> _openTelegram() async {
    final Uri url = Uri.parse(telegramUrl);
    await launchUrl(url, mode: LaunchMode.externalApplication);
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
              icon: Icon(widget.isDark ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: widget.onToggleTheme,
            ),
            TextButton(
              onPressed: widget.onToggleLanguage,
              child: Text(
                isFa ? 'EN' : 'FA',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              if (isLoading || isPinging) const LinearProgressIndicator(),
              // ... (بقیه کد UI بدون تغییر زیاد - همان کد قبلی شما)

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
                              ? (isFa ? 'در حال دریافت اطلاعات...' : 'Fetching info...')
                              : lastUpdateText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openTelegram,
                        icon: const Icon(Icons.send, size: 14),
                        label: Text(isFa ? 'تلگرام' : 'Telegram'),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // دکمه بزرگ Start/Stop
              ElevatedButton(
                onPressed: toggleConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : Colors.green,
                  minimumSize: const Size(125, 125),
                  shape: const CircleBorder(),
                ),
                child: Text(
                  isConnected
                      ? (isFa ? 'قطع' : 'STOP')
                      : (isFa ? 'شروع' : 'START'),
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFa ? 'لیست سرورها:' : 'Server List:',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton.icon(
                    onPressed: testPingAndSort,
                    icon: const Icon(Icons.speed, size: 16),
                    label: Text(
                      isFa ? 'تست پینگ واقعی' : 'Real Delay / Sort',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  itemCount: configList.length,
                  itemBuilder: (context, index) {
                    final item = configList[index];
                    final isSelected = item.rawConfig == selectedConfigRaw;
                    return Card(
                      color: isSelected ? Colors.blue.withOpacity(0.25) : null,
                      child: ListTile(
                        leading: Text(item.emoji, style: const TextStyle(fontSize: 24)),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: item.delay > 0
                            ? Text(
                                'Ping: ${item.delay} ms',
                                style: TextStyle(
                                  color: item.delay < 250 ? Colors.green : Colors.orange,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                        onTap: () {
                          setState(() {
                            selectedConfigRaw = item.rawConfig;
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
