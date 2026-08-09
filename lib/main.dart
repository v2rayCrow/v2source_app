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
  int pingProgress = 0;
  int pingTotal = 0;

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
        if (!mounted) return;
        setState(() {
          isConnected = status.state == 'CONNECTED';
        });

        if (status.state == 'ERROR') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isFa ? 'خطا در اتصال' : 'Connection error',
              ),
            ),
          );
        }
      },
    );

    v2ray.initializeV2Ray();
    fetchSubscription();

    _timer = Timer.periodic(const Duration(hours: 6), (timer) {
      if (mounted) fetchSubscription();
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
    if (!mounted) return;
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
        // معمولاً خط اول و دوم هدر هستن
        for (int i = 2; i < lines.length; i++) {
          final raw = lines[i];
          if (!raw.contains('://')) continue;

          final fullName = decodeRemark(raw);
          final emoji = extractEmoji(fullName);

          parsedConfigs.add(ConfigModel(
            rawConfig: raw,
            name: fullName,
            emoji: emoji,
          ));
        }

        if (mounted) {
          setState(() {
            configList = parsedConfigs;
            if (configList.isNotEmpty && selectedConfigRaw == null) {
              selectedConfigRaw = configList.first.rawConfig;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isFa ? 'خطا در دریافت لیست' : 'Error fetching list')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// پینگ واقعی با پارس صحیح و موازی‌سازی محدود
  Future<void> testPingAndSort() async {
    if (configList.isEmpty || isPinging || !mounted) return;

    setState(() {
      isPinging = true;
      pingProgress = 0;
      pingTotal = configList.length;
    });

    // اگر وصل بود، اول قطع کن تا پینگ دقیق‌تر باشه
    bool wasConnected = isConnected;
    String? previousConfig = selectedConfigRaw;
    if (isConnected) {
      try {
        await v2ray.stopV2Ray();
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (_) {}
    }

    const int concurrency = 5;
    int successCount = 0;

    for (int i = 0; i < configList.length; i += concurrency) {
      if (!mounted) break;

      final batch = configList.skip(i).take(concurrency).toList();

      await Future.wait(batch.map((item) async {
        try {
          final parser = FlutterV2ray.parseFromURL(item.rawConfig);
          final fullConfig = parser.getFullConfiguration();

          final delay = await v2ray.getServerDelay(config: fullConfig)
              .timeout(const Duration(seconds: 8), onTimeout: () => -1);

          item.delay = delay > 0 ? delay : -1;
          if (item.delay > 0) successCount++;
        } catch (_) {
          item.delay = -1;
        }
      }));

      if (mounted) {
        setState(() {
          pingProgress = (i + batch.length).clamp(0, configList.length);
        });
      }
    }

    // مرتب‌سازی: پینگ کمتر بالاتر
    configList.sort((a, b) {
      if (a.delay <= 0 && b.delay <= 0) return 0;
      if (a.delay <= 0) return 1;
      if (b.delay <= 0) return -1;
      return a.delay.compareTo(b.delay);
    });

    if (mounted) {
      setState(() {
        isPinging = false;
        pingProgress = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isFa
                ? 'تست پینگ انجام شد ($successCount از ${configList.length} موفق)'
                : 'Ping completed ($successCount of ${configList.length} success)',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // اگه قبلاً وصل بود، دوباره وصل نکن (کاربر خودش تصمیم بگیره)
    // اگر خواستی خودکار وصل بشه، می‌تونی اینجا previousConfig رو دوباره start کنی
  }

  void toggleConnect() async {
    if (selectedConfigRaw == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isFa
                  ? 'لطفا ابتدا یک کانفیگ انتخاب کنید'
                  : 'Please select a config first',
            ),
          ),
        );
      }
      return;
    }

    if (isConnected) {
      try {
        await v2ray.stopV2Ray();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isFa ? 'خطا در قطع اتصال' : 'Error disconnecting')),
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

      final current = configList.firstWhere(
        (element) => element.rawConfig == selectedConfigRaw,
        orElse: () => ConfigModel(
          rawConfig: selectedConfigRaw!,
          name: 'v2source',
          emoji: '🌐',
        ),
      );

      // پارس صحیح برای اتصال پایدارتر
      final parser = FlutterV2ray.parseFromURL(selectedConfigRaw!);
      final fullConfig = parser.getFullConfiguration();

      await v2ray.startV2Ray(
        remark: current.name,
        config: fullConfig,
        proxyOnly: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isFa
              ? 'خطا در شروع اتصال: $e'
              : 'Error starting connection: $e')),
        );
      }
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
              onPressed: isLoading || isPinging ? null : fetchSubscription,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (isLoading || isPinging) ...[
                LinearProgressIndicator(
                  value: isPinging && pingTotal > 0 ? pingProgress / pingTotal : null,
                ),
                if (isPinging)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isFa
                          ? 'در حال تست پینگ... $pingProgress / $pingTotal'
                          : 'Pinging... $pingProgress / $pingTotal',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],

              const SizedBox(height: 8),

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
                onPressed: isPinging ? null : toggleConnect,
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
                    onPressed: isPinging || isLoading ? null : testPingAndSort,
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
                                  color: item.delay < 250
                                      ? Colors.green
                                      : item.delay < 500
                                          ? Colors.orange
                                          : Colors.red,
                                  fontSize: 12,
                                ),
                              )
                            : item.delay == -1 && !isPinging
                                ? Text(
                                    isFa ? 'بدون پاسخ' : 'No response',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  )
                                : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: isPinging
                            ? null
                            : () {
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
