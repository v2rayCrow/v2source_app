import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
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
      _locale =
          _locale.languageCode == 'fa' ? const Locale('en') : const Locale('fa');
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

final RegExp _flagRegex = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);

final RegExp _emojiCleanupRegex = RegExp(
  r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE0F}\u{200D}]',
  unicode: true,
);

String extractFlag(String text) {
  final match = _flagRegex.firstMatch(text);
  if (match != null) return match.group(0)!;
  return '🌐';
}

String stripEmojisForDisplay(String text, bool isFa) {
  var cleaned = text.replaceAll(_emojiCleanupRegex, '');
  cleaned = cleaned.replaceAll(RegExp(r'^[\s\-–—|]+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'[\s\-–—|]+$'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  if (cleaned.isEmpty) return isFa ? 'سرور' : 'Server';
  return cleaned;
}

class ConfigModel {
  final String rawConfig;
  final String name;
  final String displayName;
  final String flag;
  int countryIndex;

  /// -1 = تست نشده، 0 = بدون پاسخ / خطا، >0 = میلی‌ثانیه
  int delay;

  String? fullConfig;

  ConfigModel({
    required this.rawConfig,
    required this.name,
    required this.displayName,
    required this.flag,
    this.countryIndex = 0,
    this.delay = -1,
    this.fullConfig,
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
  static const String subUrl =
      'https://raw.githubusercontent.com/v2rayCrow/Sub-Link-Output/main/all.txt#v2sourceALL';
  static const String githubRepo = 'v2rayCrow/v2source_app';
  static const String telegramUrl = 'https://t.me/V2Source';
  static const int _pingConcurrency = 7;

  late FlutterV2ray v2ray;
  bool isConnected = false;
  bool isLoading = false;
  bool isPinging = false;
  bool _connecting = false;
  DateTime? _lastToggleTime;

  List<ConfigModel> configList = [];
  String? selectedConfigRaw;
  String lastUpdateText = '';
  Timer? _timer;
  Timer? _sortTimer;

  int _pingDone = 0;
  int _pingTotal = 0;
  final Set<String> _testingNow = {};
  bool _cancelPing = false;

  List<String> _countryOrder = [];
  Map<String, int> _countryCounts = {};
  String? _selectedCountry;

  String _appVersion = '...';
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    _initV2Ray();
    _loadVersion();
    fetchSubscription();
    _timer = Timer.periodic(const Duration(hours: 6), (_) => fetchSubscription());
    // چک آپدیت بعد از کمی تأخیر تا UI آماده شود
    Future.delayed(const Duration(seconds: 3), _checkForUpdate);
  }

  Future<void> _initV2Ray() async {
    try {
      v2ray = FlutterV2ray(
        onStatusChanged: (status) {
          if (!mounted) return;
          setState(() {
            isConnected = status.state.toUpperCase() == 'CONNECTED';
          });
        },
      );
      await v2ray.initializeV2Ray();
    } catch (e) {
      debugPrint('v2ray init error: $e');
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = info.version);
      }
    } catch (e) {
      debugPrint('version load error: $e');
      if (mounted) setState(() => _appVersion = '1.0.5');
    }
  }

  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;
    try {
      final res = await http
          .get(
            Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
      final htmlUrl = data['html_url'] as String? ??
          'https://github.com/$githubRepo/releases/latest';

      if (tag.isEmpty || _appVersion == '...') return;

      // مقایسه ساده نسخه‌ها (مثلاً 1.0.6 > 1.0.5)
      if (_isNewerVersion(tag, _appVersion)) {
        if (!mounted) return;
        _showUpdateDialog(tag, htmlUrl);
      }
    } catch (e) {
      debugPrint('update check error: $e');
    }
  }

  bool _isNewerVersion(String remote, String local) {
    try {
      final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final l = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final rv = i < r.length ? r[i] : 0;
        final lv = i < l.length ? l[i] : 0;
        if (rv > lv) return true;
        if (rv < lv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _showUpdateDialog(String newVersion, String url) {
    final isFa = widget.isFa;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(isFa ? 'نسخه جدید موجود است' : 'Update Available'),
        content: Text(
          isFa
              ? 'نسخه $newVersion منتشر شده. می‌خواهید الان بروید به صفحه دانلود؟'
              : 'Version $newVersion is available. Go to download page?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFa ? 'بعداً' : 'Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: Text(isFa ? 'آپدیت' : 'Update'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sortTimer?.cancel();
    _cancelPing = true;
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

  String? getFullConfig(ConfigModel item) {
    if (item.fullConfig != null && item.fullConfig!.isNotEmpty) {
      return item.fullConfig;
    }
    try {
      final parser = FlutterV2ray.parseFromURL(item.rawConfig);
      final json = parser.getFullConfiguration();
      if (json.isEmpty) return null;
      // اعتبارسنجی خیلی ساده
      jsonDecode(json);
      item.fullConfig = json;
      return json;
    } catch (e) {
      debugPrint('parse error for ${item.displayName}: $e');
      return null;
    }
  }

  Future<void> fetchSubscription() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final response = await http
          .get(Uri.parse(subUrl))
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      String content = response.body.trim();
      try {
        content = utf8.decode(base64.decode(content));
      } catch (_) {}

      final lines = content
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) {
        lastUpdateText = decodeRemark(lines[0]);
      }

      final parsedConfigs = <ConfigModel>[];
      // معمولاً خط ۰ و ۱ هدر هستن؛ از خط ۲ به بعد کانفیگ‌ها
      final startIndex = lines.length > 2 ? 2 : 0;
      for (int i = startIndex; i < lines.length; i++) {
        final raw = lines[i];
        if (!raw.contains('://')) continue;
        try {
          final fullName = decodeRemark(raw);
          final flag = extractFlag(fullName);
          parsedConfigs.add(
            ConfigModel(
              rawConfig: raw,
              name: fullName,
              displayName: stripEmojisForDisplay(fullName, widget.isFa),
              flag: flag,
            ),
          );
        } catch (e) {
          debugPrint('skip bad line: $e');
        }
      }

      // شماره‌گذاری سرورهای هم‌پرچم
      final counts = <String, int>{};
      final seenPerCountry = <String, int>{};
      for (final c in parsedConfigs) {
        counts[c.flag] = (counts[c.flag] ?? 0) + 1;
        final n = (seenPerCountry[c.flag] ?? 0) + 1;
        seenPerCountry[c.flag] = n;
        c.countryIndex = n;
      }

      final order = counts.keys.toList()
        ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

      if (mounted) {
        setState(() {
          configList = parsedConfigs;
          _countryCounts = counts;
          _countryOrder = order;
          _selectedCountry = null;
          selectedConfigRaw = null;
        });
      }
    } catch (e) {
      debugPrint('fetch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isFa ? 'خطا در دریافت لیست سرورها' : 'Error fetching server list',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  int _compareByDelay(ConfigModel a, ConfigModel b) {
    int rank(ConfigModel c) {
      if (c.delay < 0) return 2; // تست‌نشده
      if (c.delay == 0) return 1; // مرده
      return 0; // زنده
    }

    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    if (ra == 0) return a.delay.compareTo(b.delay);
    return a.displayName.compareTo(b.displayName);
  }

  List<ConfigModel> get _visibleConfigs {
    if (_selectedCountry == null) return List<ConfigModel>.from(configList);
    return configList.where((c) => c.flag == _selectedCountry).toList();
  }

  Future<void> testPingAndSort() async {
    if (isPinging) return;
    if (isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isFa
                ? 'برای تست پینگ، ابتدا اتصال را قطع کنید'
                : 'Disconnect before running a ping test',
          ),
        ),
      );
      return;
    }

    // لیست ثابتی از ارجاعات — تا نتایج جابه‌جا نشوند
    final toTest = List<ConfigModel>.from(_visibleConfigs);
    if (toTest.isEmpty) return;

    // ریست پینگ‌های قبلی همین لیست
    for (final c in toTest) {
      c.delay = -1;
    }

    setState(() {
      isPinging = true;
      _cancelPing = false;
      _pingDone = 0;
      _pingTotal = toTest.length;
      _testingNow.clear();
    });

    _sortTimer?.cancel();
    _sortTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted || _cancelPing) return;
      setState(() => configList.sort(_compareByDelay));
    });

    Future<int> testOnce(ConfigModel item) async {
      try {
        final fullConfig = getFullConfig(item);
        if (fullConfig == null || fullConfig.isEmpty) return 0;

        final delay = await v2ray
            .getServerDelay(
              config: fullConfig,
              url: 'https://www.gstatic.com/generate_204',
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => -1,
            );

        // getServerDelay معمولاً -1 برمی‌گرداند وقتی شکست بخورد
        if (delay < 0) return 0;
        return delay;
      } catch (e) {
        debugPrint('ping error [${item.displayName}]: $e');
        return 0;
      }
    }

    // صف امن بدون race روی اندیس
    final queue = List<ConfigModel>.from(toTest);
    int queueIndex = 0;

    Future<void> worker() async {
      while (!_cancelPing) {
        ConfigModel? item;
        // گرفتن بعدی به صورت sequential در isolate اصلی (امن است)
        if (queueIndex >= queue.length) return;
        item = queue[queueIndex++];
        if (item == null) return;

        final current = item;
        if (mounted) {
          setState(() => _testingNow.add(current.rawConfig));
        }

        int delay = 0;
        if (!_cancelPing) {
          delay = await testOnce(current);
          // یک بار تلاش مجدد برای نتایج صفر (گاهی شبکه لحظه‌ای قطع است)
          if (delay == 0 && !_cancelPing) {
            await Future.delayed(const Duration(milliseconds: 300));
            delay = await testOnce(current);
          }
        }

        // فقط روی همان آبجکت بنویس — جابه‌جایی پیش نمی‌آید
        current.delay = delay > 0 ? delay : 0;

        if (mounted) {
          setState(() {
            _pingDone++;
            _testingNow.remove(current.rawConfig);
          });
        }

        // کمی فاصله برای جلوگیری از فشار زیاد روی core
        await Future.delayed(const Duration(milliseconds: 80));
      }
    }

    try {
      await Future.wait(
        List.generate(_pingConcurrency, (_) => worker()),
      );
    } catch (e) {
      debugPrint('ping workers error: $e');
    } finally {
      _sortTimer?.cancel();
      _sortTimer = null;
      if (mounted) {
        setState(() {
          configList.sort(_compareByDelay);
          isPinging = false;
          _testingNow.clear();
        });
        if (!_cancelPing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isFa
                    ? 'تست پینگ انجام شد ($_pingDone/$_pingTotal)'
                    : 'Ping test done ($_pingDone/$_pingTotal)',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void stopPing() {
    _cancelPing = true;
    _sortTimer?.cancel();
    if (mounted) {
      setState(() {
        isPinging = false;
        _testingNow.clear();
        configList.sort(_compareByDelay);
      });
    }
  }

  void _showSnack(String fa, String en) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.isFa ? fa : en)),
    );
  }

  Future<bool> _startConnection(ConfigModel item) async {
    try {
      final permission = await v2ray.requestPermission();
      if (!permission) {
        _showSnack('دسترسی VPN رد شد', 'VPN permission denied');
        return false;
      }

      final fullConfig = getFullConfig(item);
      if (fullConfig == null || fullConfig.isEmpty) {
        _showSnack(
          'این کانفیگ قابل استفاده نیست (نامعتبر)',
          'This config is invalid',
        );
        return false;
      }

      // توقف هر اتصال قبلی قبل از شروع جدید
      try {
        await v2ray.stopV2Ray();
      } catch (_) {}

      await v2ray.startV2Ray(
        remark: item.name.isNotEmpty ? item.name : 'v2source',
        config: fullConfig,
        proxyOnly: false,
      );
      return true;
    } catch (e) {
      debugPrint('start error: $e');
      try {
        await v2ray.stopV2Ray();
      } catch (_) {}
      if (mounted) setState(() => isConnected = false);
      _showSnack('خطا در شروع اتصال', 'Connect error');
      return false;
    }
  }

  Future<void> toggleConnect() async {
    final now = DateTime.now();
    if (_lastToggleTime != null &&
        now.difference(_lastToggleTime!).inMilliseconds < 900) {
      return;
    }
    _lastToggleTime = now;

    if (_connecting) return;

    if (isConnected) {
      _connecting = true;
      try {
        await v2ray.stopV2Ray();
        if (mounted) setState(() => isConnected = false);
      } catch (e) {
        debugPrint('stop error: $e');
        _showSnack('خطا در قطع اتصال', 'Disconnect error');
      } finally {
        _connecting = false;
      }
      return;
    }

    if (selectedConfigRaw == null) {
      _showSnack(
        'لطفا ابتدا یک کانفیگ انتخاب کنید',
        'Please select a config first',
      );
      return;
    }

    final item = configList.cast<ConfigModel?>().firstWhere(
          (c) => c?.rawConfig == selectedConfigRaw,
          orElse: () => null,
        );
    if (item == null) {
      _showSnack('کانفیگ پیدا نشد', 'Config not found');
      return;
    }

    _connecting = true;
    if (mounted) setState(() {});
    try {
      final ok = await _startConnection(item);
      if (mounted) {
        setState(() => isConnected = ok);
      }
    } finally {
      _connecting = false;
      if (mounted) setState(() {});
    }
  }

  void onConfigTap(ConfigModel item) {
    if (isConnected) {
      _showSnack(
        'ابتدا اتصال را قطع کنید',
        'Disconnect first',
      );
      return;
    }
    setState(() => selectedConfigRaw = item.rawConfig);
  }

  Widget _buildSubtitle(ConfigModel item, bool isFa) {
    if (_testingNow.contains(item.rawConfig)) {
      return Text(
        isFa ? 'در حال تست...' : 'Testing...',
        style: TextStyle(color: Colors.orange[300], fontSize: 12),
      );
    }
    if (item.delay < 0) {
      return Text(
        isFa ? 'تست نشده' : 'Not tested',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      );
    }
    if (item.delay == 0) {
      return Text(
        isFa ? 'بدون پاسخ' : 'No response',
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }
    Color color;
    if (item.delay < 300) {
      color = Colors.green;
    } else if (item.delay < 700) {
      color = Colors.lightGreen;
    } else if (item.delay < 1200) {
      color = Colors.orange;
    } else {
      color = Colors.redAccent;
    }
    return Text(
      '${item.delay} ms',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFa = widget.isFa;
    final visible = _visibleConfigs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('v2source'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isFa ? 'تغییر زبان' : 'Toggle language',
            icon: const Icon(Icons.language),
            onPressed: widget.onToggleLanguage,
          ),
          IconButton(
            tooltip: isFa ? 'تم روشن/تاریک' : 'Toggle theme',
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            tooltip: 'Telegram',
            icon: const Icon(Icons.telegram),
            onPressed: () => launchUrl(
              Uri.parse(telegramUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // نوار وضعیت + دکمه‌ها
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_connecting || isLoading)
                          ? null
                          : toggleConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isConnected ? Colors.redAccent : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _connecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isConnected ? Icons.link_off : Icons.power_settings_new),
                      label: Text(
                        _connecting
                            ? (isFa ? 'صبر کنید...' : 'Please wait...')
                            : isConnected
                                ? (isFa ? 'قطع اتصال' : 'Disconnect')
                                : (isFa ? 'اتصال' : 'Connect'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: isLoading ? null : fetchSubscription,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: isFa ? 'بروزرسانی لیست' : 'Refresh list',
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    onPressed: isPinging ? stopPing : testPingAndSort,
                    icon: isPinging
                        ? const Icon(Icons.stop)
                        : const Icon(Icons.speed),
                    tooltip: isPinging
                        ? (isFa ? 'توقف پینگ' : 'Stop ping')
                        : (isFa ? 'تست پینگ' : 'Ping test'),
                  ),
                ],
              ),
            ),

            // پیشرفت پینگ
            if (isPinging)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _pingTotal == 0 ? null : _pingDone / _pingTotal,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFa
                          ? 'پینگ: $_pingDone / $_pingTotal'
                          : 'Ping: $_pingDone / $_pingTotal',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

            // فیلتر کشورها
            if (_countryOrder.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(
                          isFa
                              ? 'همه (${configList.length})'
                              : 'All (${configList.length})',
                        ),
                        selected: _selectedCountry == null,
                        onSelected: (_) {
                          setState(() => _selectedCountry = null);
                        },
                      ),
                    ),
                    ..._countryOrder.map((flag) {
                      final count = _countryCounts[flag] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text('$flag $count'),
                          selected: _selectedCountry == flag,
                          onSelected: (_) {
                            setState(() {
                              _selectedCountry =
                                  _selectedCountry == flag ? null : flag;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // لیست سرورها
            Expanded(
              child: isLoading && configList.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? Center(
                          child: Text(
                            isFa ? 'سروری پیدا نشد' : 'No servers found',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            final isSelected =
                                item.rawConfig == selectedConfigRaw;
                            return Card(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.22)
                                  : null,
                              child: ListTile(
                                leading: SizedBox(
                                  width: 40,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.flag,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      if (item.countryIndex > 0)
                                        Text(
                                          '#${item.countryIndex}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                title: Text(
                                  item.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: _buildSubtitle(item, isFa),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: isConnected
                                            ? Colors.green
                                            : Colors.blue,
                                      )
                                    : null,
                                onTap: () => onConfigTap(item),
                              ),
                            );
                          },
                        ),
            ),

            // نسخه پایین صفحه
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: Text(
                'v$_appVersion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
