import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// نام کشورها بر اساس پرچم
const Map<String, List<String>> _flagCountryNames = {
  '🇺🇸': ['آمریکا', 'USA'],
  '🇬🇧': ['انگلیس', 'UK'],
  '🇩🇪': ['آلمان', 'Germany'],
  '🇫🇷': ['فرانسه', 'France'],
  '🇳🇱': ['هلند', 'Netherlands'],
  '🇸🇬': ['سنگاپور', 'Singapore'],
  '🇯🇵': ['ژاپن', 'Japan'],
  '🇰🇷': ['کره جنوبی', 'South Korea'],
  '🇭🇰': ['هنگ کنگ', 'Hong Kong'],
  '🇹🇼': ['تایوان', 'Taiwan'],
  '🇨🇳': ['چین', 'China'],
  '🇷🇺': ['روسیه', 'Russia'],
  '🇹🇷': ['ترکیه', 'Turkey'],
  '🇮🇷': ['ایران', 'Iran'],
  '🇮🇳': ['هند', 'India'],
  '🇨🇦': ['کانادا', 'Canada'],
  '🇦🇺': ['استرالیا', 'Australia'],
  '🇧🇷': ['برزیل', 'Brazil'],
  '🇮🇹': ['ایتالیا', 'Italy'],
  '🇪🇸': ['اسپانیا', 'Spain'],
  '🇵🇹': ['پرتغال', 'Portugal'],
  '🇨🇭': ['سوئیس', 'Switzerland'],
  '🇦🇹': ['اتریش', 'Austria'],
  '🇧🇪': ['بلژیک', 'Belgium'],
  '🇸🇪': ['سوئد', 'Sweden'],
  '🇳🇴': ['نروژ', 'Norway'],
  '🇫🇮': ['فنلاند', 'Finland'],
  '🇩🇰': ['دانمارک', 'Denmark'],
  '🇵🇱': ['لهستان', 'Poland'],
  '🇨🇿': ['چک', 'Czechia'],
  '🇭🇺': ['مجارستان', 'Hungary'],
  '🇬🇷': ['یونان', 'Greece'],
  '🇮🇪': ['ایرلند', 'Ireland'],
  '🇺🇦': ['اوکراین', 'Ukraine'],
  '🇮🇱': ['اسرائیل', 'Israel'],
  '🇦🇪': ['امارات', 'UAE'],
  '🇸🇦': ['عربستان', 'Saudi Arabia'],
  '🇿🇦': ['آفریقای جنوبی', 'South Africa'],
  '🇲🇽': ['مکزیک', 'Mexico'],
  '🇦🇷': ['آرژانتین', 'Argentina'],
  '🇨🇱': ['شیلی', 'Chile'],
  '🇮🇩': ['اندونزی', 'Indonesia'],
  '🇲🇾': ['مالزی', 'Malaysia'],
  '🇹🇭': ['تایلند', 'Thailand'],
  '🇻🇳': ['ویتنام', 'Vietnam'],
  '🇵🇭': ['فیلیپین', 'Philippines'],
  '🇷🇴': ['رومانی', 'Romania'],
  '🇧🇬': ['بلغارستان', 'Bulgaria'],
  '🇭🇷': ['کرواسی', 'Croatia'],
  '🇷🇸': ['صربستان', 'Serbia'],
  '🇸🇮': ['اسلوونی', 'Slovenia'],
  '🇸🇰': ['اسلواکی', 'Slovakia'],
  '🇱🇹': ['لیتوانی', 'Lithuania'],
  '🇱🇻': ['لتونی', 'Latvia'],
  '🇪🇪': ['استونی', 'Estonia'],
  '🇮🇸': ['ایسلند', 'Iceland'],
  '🇱🇺': ['لوکزامبورگ', 'Luxembourg'],
  '🇲🇹': ['مالت', 'Malta'],
  '🇨🇾': ['قبرس', 'Cyprus'],
  '🇪🇬': ['مصر', 'Egypt'],
  '🇳🇬': ['نیجریه', 'Nigeria'],
  '🇰🇪': ['کنیا', 'Kenya'],
  '🇵🇰': ['پاکستان', 'Pakistan'],
  '🇧🇩': ['بنگلادش', 'Bangladesh'],
  '🇳🇿': ['نیوزیلند', 'New Zealand'],
  '🇰🇿': ['قزاقستان', 'Kazakhstan'],
  '🇬🇪': ['گرجستان', 'Georgia'],
  '🇦🇲': ['ارمنستان', 'Armenia'],
  '🇦🇿': ['آذربایجان', 'Azerbaijan'],
  '🇲🇩': ['مولداوی', 'Moldova'],
  '🇧🇾': ['بلاروس', 'Belarus'],
  '🇮🇶': ['عراق', 'Iraq'],
  '🇶🇦': ['قطر', 'Qatar'],
  '🇰🇼': ['کویت', 'Kuwait'],
  '🇧🇭': ['بحرین', 'Bahrain'],
  '🇴🇲': ['عمان', 'Oman'],
  '🇯🇴': ['اردن', 'Jordan'],
  '🇱🇧': ['لبنان', 'Lebanon'],
};

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

String countryLabel(String flag, bool isFa) {
  final entry = _flagCountryNames[flag];
  if (entry == null) return '';
  return isFa ? entry[0] : entry[1];
}

class ConfigModel {
  final String rawConfig;
  final String name;
  final String displayName;
  final String flag;

  int countryIndex;

  /// -1 = تست نشده، 0 = بدون پاسخ، >0 = میلی‌ثانیه
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
  final String subUrl =
      'https://raw.githubusercontent.com/v2rayCrow/Sub-Link-Output/main/all.txt#v2sourceALL';

  late FlutterV2ray v2ray;
  bool isConnected = false;
  bool isLoading = false;
  bool isPinging = false;

  bool _connecting = false;
  DateTime? _lastToggleTime;

  List<ConfigModel> configList = [];
  String? selectedConfigRaw;
  String lastUpdateText = '';
  final String telegramUrl = 'https://t.me/V2Source';
  Timer? _timer;

  int _pingDone = 0;
  int _pingTotal = 0;
  Timer? _sortTimer;
  final Set<String> _testingNow = {};
  bool _cancelPing = false;

  List<String> _countryOrder = [];
  Map<String, int> _countryCounts = {};
  String? _selectedCountry;

  // تعداد تست هم‌زمان — بالاتر = سریع‌تر؛ بیش از حد ممکن است باعث خطای هسته شود
  static const int _pingConcurrency = 6;

  @override
  void initState() {
    super.initState();
    try {
      v2ray = FlutterV2ray(
        onStatusChanged: (status) {
          if (!mounted) return;
          setState(() {
            isConnected = status.state == 'CONNECTED';
          });
        },
      );
      v2ray.initializeV2Ray();
    } catch (e) {
      debugPrint('v2ray init error: $e');
    }
    fetchSubscription();
    _timer = Timer.periodic(const Duration(hours: 6), (_) => fetchSubscription());
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
      item.fullConfig = json;
      return json;
    } catch (e) {
      debugPrint('parse error: $e');
      return null;
    }
  }

  Future<void> fetchSubscription() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final response = await http
          .get(Uri.parse(subUrl))
          .timeout(const Duration(seconds: 20));
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
          if (!raw.contains('://')) continue;
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
        }

        final counts = <String, int>{};
        for (final c in parsedConfigs) {
          counts[c.flag] = (counts[c.flag] ?? 0) + 1;
        }
        final order = counts.keys.toList()
          ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

        final seenPerCountry = <String, int>{};
        for (final c in parsedConfigs) {
          final n = (seenPerCountry[c.flag] ?? 0) + 1;
          seenPerCountry[c.flag] = n;
          c.countryIndex = n;
        }

        if (!mounted) return;
        setState(() {
          configList = parsedConfigs;
          _countryCounts = counts;
          _countryOrder = order;
          _selectedCountry = null;
          if (configList.isNotEmpty && selectedConfigRaw == null) {
            selectedConfigRaw = configList.first.rawConfig;
          }
        });
      }
    } catch (e) {
      debugPrint('fetch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isFa ? 'خطا در دریافت لیست' : 'Error fetching list',
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
      if (c.delay < 0) return 2;
      if (c.delay == 0) return 1;
      return 0;
    }

    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    if (ra == 0) return a.delay.compareTo(b.delay);
    return 0;
  }

  List<ConfigModel> get _visibleConfigs {
    if (_selectedCountry == null) return List<ConfigModel>.from(configList);
    return configList.where((c) => c.flag == _selectedCountry).toList();
  }

  /// استخراج host و port از لینک‌های رایج (vmess / vless / trojan / ss / ...)
  (String?, int?) _extractHostPort(String raw) {
    try {
      final uri = Uri.parse(raw);
      final scheme = uri.scheme.toLowerCase();

      if (scheme == 'vmess') {
        // vmess://BASE64  یا  vmess://BASE64?...
        String payload = uri.hasAuthority ? uri.authority : uri.path;
        if (payload.isEmpty && uri.path.isNotEmpty) payload = uri.path;
        // بعضی لینک‌ها بعد از base64 کوئری دارند
        final q = payload.indexOf('?');
        if (q >= 0) payload = payload.substring(0, q);
        final normalized = base64.normalize(payload);
        final decoded = utf8.decode(base64.decode(normalized));
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        final host = json['add']?.toString();
        final port = int.tryParse(json['port']?.toString() ?? '');
        return (host, port);
      }

      // vless://uuid@host:port  /  trojan://...@host:port  /  ss://...@host:port
      if (uri.host.isNotEmpty) {
        final port = uri.hasPort ? uri.port : null;
        if (port != null && port > 0) return (uri.host, port);
      }

      // fallback: regex برای host:port در رشته
      final m = RegExp(r'@([^:@\s/]+):(\d+)').firstMatch(raw);
      if (m != null) {
        return (m.group(1), int.tryParse(m.group(2)!));
      }
    } catch (_) {}
    return (null, null);
  }

  /// پیش‌تست سریع TCP — فقط برای رد کردن سرورهای قطعاً مرده
  /// اگر host/port معلوم نباشد یا کانکت نشود، باز هم true برمی‌گرداند
  /// تا تست واقعی V2Ray از دست نرود (علت اصلی «در ویتوری پینگ داره اینجا نداره»).
  Future<bool> _quickTcpCheck(ConfigModel item) async {
    try {
      final (host, port) = _extractHostPort(item.rawConfig);
      if (host == null || port == null) return true;

      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 1200),
      );
      socket.destroy();
      return true;
    } catch (_) {
      // ممکن است پورت از بیرون بسته باشد ولی از داخل تونل جواب بدهد؛
      // برای دقت بیشتر، false قطعی نمی‌دهیم و تست V2Ray را اجرا می‌کنیم.
      return true;
    }
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

    final toTest = List<ConfigModel>.from(_visibleConfigs);
    if (toTest.isEmpty) return;

    // ریست پینگ‌های قبلی تا مرتب‌سازی تمیز باشد
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
    _sortTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _cancelPing) return;
      setState(() => configList.sort(_compareByDelay));
    });

    Future<int> testOnce(ConfigModel item) async {
      try {
        final fullConfig = getFullConfig(item);
        if (fullConfig == null || fullConfig.isEmpty) return -1;
        final delay = await v2ray
            .getServerDelay(
              config: fullConfig,
              url: 'https://www.gstatic.com/generate_204',
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => -1,
            );
        return delay;
      } catch (e) {
        debugPrint('ping error: $e');
        return -1;
      }
    }

    int nextIndex = 0;

    Future<void> worker() async {
      while (!_cancelPing) {
        final i = nextIndex++;
        if (i >= toTest.length) return;

        final item = toTest[i];
        if (mounted) {
          setState(() => _testingNow.add(item.rawConfig));
        }

        int delay = -1;
        if (!_cancelPing) {
          // پیش‌تست TCP فقط برای لاگ/آینده؛ دیگر سرور را حذف نمی‌کند
          await _quickTcpCheck(item);
          delay = await testOnce(item);
          // یک بار retry کوتاه در صورت خطای موقتی
          if (delay <= 0 && !_cancelPing) {
            await Future.delayed(const Duration(milliseconds: 120));
            delay = await testOnce(item);
          }
        }

        item.delay = delay > 0 ? delay : 0;

        _pingDone++;
        if (mounted) {
          setState(() => _testingNow.remove(item.rawConfig));
        }
        // فاصله خیلی کوتاه بین درخواست‌ها تا هسته overload نشود
        await Future.delayed(const Duration(milliseconds: 40));
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
        _showSnack('کانفیگ نامعتبر است', 'Invalid config');
        return false;
      }

      await v2ray.startV2Ray(
        remark: item.name,
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
      _showSnack('خطا در شروع اتصال: $e', 'Connect error: $e');
      return false;
    }
  }

  Future<void> toggleConnect() async {
    final now = DateTime.now();
    if (_lastToggleTime != null &&
        now.difference(_lastToggleTime!).inMilliseconds < 800) {
      return;
    }
    _lastToggleTime = now;

    if (_connecting) return;
    if (selectedConfigRaw == null) {
      _showSnack('لطفا ابتدا یک کانفیگ انتخاب کنید', 'Please select a config first');
      return;
    }

    if (isConnected) {
      _connecting = true;
      try {
        await v2ray.stopV2Ray();
      } catch (e) {
        debugPrint('stop error: $e');
      } finally {
        _connecting = false;
        if (mounted) setState(() => isConnected = false);
      }
      return;
    }

    _connecting = true;
    try {
      final current = configList.firstWhere(
        (e) => e.rawConfig == selectedConfigRaw,
        orElse: () => ConfigModel(
          rawConfig: selectedConfigRaw!,
          name: 'v2source',
          displayName: 'v2source',
          flag: '🌐',
        ),
      );
      await _startConnection(current);
    } finally {
      _connecting = false;
    }
  }

  Future<void> onConfigTap(ConfigModel item) async {
    if (item.rawConfig == selectedConfigRaw && !isConnected) return;
    if (item.rawConfig == selectedConfigRaw && isConnected) return;

    if (!isConnected) {
      setState(() => selectedConfigRaw = item.rawConfig);
      return;
    }

    if (_connecting) return;
    _connecting = true;
    setState(() {
      selectedConfigRaw = item.rawConfig;
      isConnected = false;
    });
    try {
      try {
        await v2ray.stopV2Ray();
      } catch (e) {
        debugPrint('stop-before-switch error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || selectedConfigRaw != item.rawConfig) return;
      await _startConnection(item);
    } finally {
      _connecting = false;
    }
  }

  Future<void> _openTelegram() async {
    final Uri url = Uri.parse(telegramUrl);
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // --- تنظیم مجدد بازه‌های رنگ‌بندی پینگ (جدید) ---
  Color _getPingColor(int delay) {
    if (delay <= 700) return Colors.green;
    if (delay <= 1500) return Colors.orange;
    return Colors.redAccent;
  }

  Widget? _buildSubtitle(ConfigModel item, bool isFa) {
    if (_testingNow.contains(item.rawConfig)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 6),
          Text(
            isFa ? 'در حال تست...' : 'Testing...',
            style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
          ),
        ],
      );
    }
    if (item.delay > 0) {
      return Text(
        'Ping: ${item.delay} ms',
        style: TextStyle(
          color: _getPingColor(item.delay),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (item.delay == 0) {
      return Text(
        isFa ? 'بدون پاسخ (-1)' : 'No response (-1)',
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }
    return null;
  }

  Widget _buildCountryStrip(bool isFa) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
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
            final label = countryLabel(flag, isFa);
            final text = label.isEmpty
                ? '$flag ($count)'
                : '$flag $label ($count)';
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(text, style: const TextStyle(fontSize: 13)),
                selected: _selectedCountry == flag,
                onSelected: (_) {
                  setState(() => _selectedCountry = flag);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFa = widget.isFa;
    final visibleConfigs = _visibleConfigs;

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
              onPressed: (isLoading || isPinging) ? null : fetchSubscription,
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
                              ? (isFa
                                  ? 'در حال دریافت اطلاعات...'
                                  : 'Fetching info...')
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: isPinging ? stopPing : testPingAndSort,
                    icon: Icon(
                      isPinging ? Icons.stop : Icons.speed,
                      size: 16,
                    ),
                    label: Text(
                      isPinging
                          ? '$_pingDone/$_pingTotal  ${isFa ? "توقف" : "Stop"}'
                          : (isFa ? 'تست پینگ واقعی' : 'Real Delay / Sort'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              _buildCountryStrip(isFa),
              const SizedBox(height: 8),

              Expanded(
                child: visibleConfigs.isEmpty
                    ? Center(
                        child: Text(
                          isFa ? 'کانفیگی یافت نشد' : 'No configs found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visibleConfigs.length,
                        itemBuilder: (context, index) {
                          final item = visibleConfigs[index];
                          final isSelected =
                              item.rawConfig == selectedConfigRaw;
                          return Card(
                            color: isSelected
                                ? Colors.blue.withOpacity(0.25)
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
            ],
          ),
        ),
      ),
    );
  }
}
