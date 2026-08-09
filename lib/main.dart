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
  final String telegramUrl = 'https://t.me/V2Source';
  Timer? _timer;

  // Ping test progress + live-sort state
  int _pingDone = 0;
  int _pingTotal = 0;
  Timer? _sortTimer;

  // Keep this LOW. The underlying v2ray/xray core is not designed for
  // hammering many delay-tests back to back — pushing concurrency too
  // high (or looping through hundreds sequentially with no pause) is
  // what causes the native core to crash and the app process to get
  // flagged "bad" by Android, which then blocks the VPN service from
  // starting until the flag clears.
  static const int _pingConcurrency = 3;

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
    _timer = Timer.periodic(const Duration(hours: 6), (_) => fetchSubscription());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sortTimer?.cancel();
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

  /// تبدیل لینک share به JSON کامل
  String? getFullConfig(String raw) {
    try {
      final parser = FlutterV2ray.parseFromURL(raw);
      return parser.getFullConfiguration();
    } catch (_) {
      return null;
    }
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

        final lines = content
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          lastUpdateText = decodeRemark(lines[0]);
        }

        final parsedConfigs = <ConfigModel>[];
        for (int i = 2; i < lines.length; i++) {
          final raw = lines[i];
          final fullName = decodeRemark(raw);
          parsedConfigs.add(ConfigModel(
            rawConfig: raw,
            name: fullName,
            emoji: extractEmoji(fullName),
          ));
        }

        setState(() {
          configList = parsedConfigs;
          if (configList.isNotEmpty && selectedConfigRaw == null) {
            selectedConfigRaw = configList.first.rawConfig;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isFa ? 'خطا در دریافت لیست' : 'Error fetching list')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  int _compareByDelay(ConfigModel a, ConfigModel b) {
    if (a.delay <= 0 && b.delay <= 0) return 0;
    if (a.delay <= 0) return 1;
    if (b.delay <= 0) return -1;
    return a.delay.compareTo(b.delay);
  }

  Future<void> testPingAndSort() async {
    if (configList.isEmpty || isPinging) return;

    setState(() {
      isPinging = true;
      _pingDone = 0;
      _pingTotal = configList.length;
    });

    // Re-sort + rebuild on a timer instead of after every single result.
    // With ~400 items, sorting/rebuilding on every completion would be
    // both slow and would spam the native side; every 400ms is frequent
    // enough to feel "live" without hammering anything.
    _sortTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() => configList.sort(_compareByDelay));
    });

    final queue = List<ConfigModel>.from(configList);
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= queue.length) return;
        final item = queue[nextIndex++];
        try {
          final fullConfig = getFullConfig(item.rawConfig);
          if (fullConfig == null) {
            item.delay = -1;
          } else {
            final delay = await v2ray
                .getServerDelay(config: fullConfig)
                .timeout(const Duration(seconds: 8), onTimeout: () => -1);
            item.delay = delay > 0 ? delay : -1;
          }
        } catch (_) {
          item.delay = -1;
        }
        _pingDone++;
        if (mounted) setState(() {});
        // Small breathing room between tests on this worker so we don't
        // fire requests at the native core back-to-back.
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }

    try {
      await Future.wait(List.generate(_pingConcurrency, (_) => worker()));
    } finally {
      _sortTimer?.cancel();
      _sortTimer = null;
      if (mounted) {
        setState(() {
          configList.sort(_compareByDelay);
          isPinging = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isFa
                ? 'تست پینگ انجام شد و لیست مرتب گردید'
                : 'Ping test completed & list sorted'),
          ),
        );
      }
    }
  }

  Future<void> toggleConnect() async {
    if (selectedConfigRaw == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isFa
              ? 'لطفا ابتدا یک کانفیگ انتخاب کنید'
              : 'Please select a config first'),
        ),
      );
      return;
    }

    if (isConnected) {
      try {
        await v2ray.stopV2Ray();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isFa ? 'خطا در قطع اتصال: $e' : 'Stop error: $e')),
          );
        }
      }
      return;
    }

    try {
      final permission = await v2ray.requestPermission();
      if (!permission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isFa ? 'دسترسی VPN رد شد' : 'VPN permission denied')),
          );
        }
        return;
      }

      final fullConfig = getFullConfig(selectedConfigRaw!);
      if (fullConfig == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isFa ? 'کانفیگ نامعتبر است' : 'Invalid config')),
          );
        }
        return;
      }

      final current = configList.firstWhere(
        (e) => e.rawConfig == selectedConfigRaw,
        orElse: () => ConfigModel(rawConfig: selectedConfigRaw!, name: 'v2source', emoji: '🌐'),
      );

      await v2ray.startV2Ray(
        remark: current.name,
        config: fullConfig,
        proxyOnly: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isFa ? 'خطا در اتصال: $e' : 'Start error: $e')),
        );
      }
    }
  }

  Future<void> _openTelegram() async {
    await launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication);
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
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: toggleConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : Colors.green,
                  minimumSize: const Size(125, 125),
                  shape: const CircleBorder(),
                ),
                child: Text(
                  isConnected ? (isFa ? 'قطع' : 'STOP') : (isFa ? 'شروع' : 'START'),
                  style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
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
                    onPressed: isPinging ? null : testPingAndSort,
                    icon: const Icon(Icons.speed, size: 16),
                    label: Text(
                      isPinging
                          ? '$_pingDone/$_pingTotal'
                          : (isFa ? 'تست پینگ واقعی' : 'Real Delay / Sort'),
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
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: () {
                          setState(() => selectedConfigRaw = item.rawConfig);
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
