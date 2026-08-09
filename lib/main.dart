import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  // runZonedGuarded + FlutterError.onError catch errors that would
  // otherwise bubble up and kill the whole app (e.g. async errors that
  // happen outside a try/catch, or framework build errors). This keeps
  // the app alive/usable instead of hard-crashing on unexpected errors.
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

/// Regional-indicator pair -> flag country name (fa/en). Covers the
/// countries that most commonly show up in these subscription lists.
/// Anything not in this table still works fine — it just won't show a
/// text label under the flag chip, the flag itself is still shown.
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

// Matches exactly a flag (two regional-indicator symbols).
final RegExp _flagRegex = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);

// Broad emoji cleanup range, used to strip emoji out of the visible
// server name text (since the flag is already shown as a big leading
// icon, we don't need it duplicated inside the title too).
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
  // Clean up leftover separators/whitespace the emoji removal exposes.
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
  final String name; // original remark, unstripped (used for start remark)
  final String displayName; // emoji stripped, used for the title
  final String flag; // extracted flag emoji, used as leading icon + group key
  int delay; // -1 = not tested yet, 0 = tested & failed, >0 = ms

  ConfigModel({
    required this.rawConfig,
    required this.name,
    required this.displayName,
    required this.flag,
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

  // Guards against rapid/overlapping connect-disconnect taps, which is
  // what was driving the underlying v2ray/xray core into a bad state
  // and eventually refusing to connect at all.
  bool _connecting = false;
  DateTime? _lastToggleTime;

  List<ConfigModel> configList = [];
  String? selectedConfigRaw;
  String lastUpdateText = '';
  final String telegramUrl = 'https://t.me/V2Source';
  Timer? _timer;

  // Ping test progress + live-sort state
  int _pingDone = 0;
  int _pingTotal = 0;
  Timer? _sortTimer;
  final Set<String> _testingNow = {};

  // Country grouping (list on top of the server list)
  List<String> _countryOrder = [];
  Map<String, int> _countryCounts = {};
  String? _selectedCountry;

  // Keep this reasonably low. The underlying v2ray/xray core is not
  // designed for hammering many delay-tests back to back — pushing
  // concurrency too high (or looping through hundreds sequentially with
  // no pause) is what causes the native core to crash and the app
  // process to get flagged "bad" by Android, which then blocks the VPN
  // service from starting until the flag clears. 5 is a good balance
  // between "feels live" and not overloading the core.
  static const int _pingConcurrency = 5;

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
    if (mounted) setState(() => isLoading = true);
    try {
      final response =
          await http.get(Uri.parse(subUrl)).timeout(const Duration(seconds: 15));
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
          final flag = extractFlag(fullName);
          parsedConfigs.add(ConfigModel(
            rawConfig: raw,
            name: fullName,
            displayName: stripEmojisForDisplay(fullName, widget.isFa),
            flag: flag,
          ));
        }

        // Group by country (flag) and sort groups by config count desc,
        // so the first tab is always the country with the most configs.
        final counts = <String, int>{};
        for (final c in parsedConfigs) {
          counts[c.flag] = (counts[c.flag] ?? 0) + 1;
        }
        final order = counts.keys.toList()
          ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

        if (!mounted) return;
        setState(() {
          configList = parsedConfigs;
          _countryCounts = counts;
          _countryOrder = order;
          if (_selectedCountry == null || !order.contains(_selectedCountry)) {
            _selectedCountry = order.isNotEmpty ? order.first : null;
          }
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  int _compareByDelay(ConfigModel a, ConfigModel b) {
    // Untested (-1) always sinks below tested entries; among tested
    // entries, failed (0) sinks below successful ones; success sorts
    // by lowest ms first.
    int rank(ConfigModel c) => c.delay < 0 ? 2 : (c.delay == 0 ? 1 : 0);
    final ra = rank(a), rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    if (ra == 0) return a.delay.compareTo(b.delay);
    return 0;
  }

  List<ConfigModel> get _visibleConfigs {
    if (_selectedCountry == null) return configList;
    return configList.where((c) => c.flag == _selectedCountry).toList();
  }

  Future<void> testPingAndSort() async {
    if (configList.isEmpty || isPinging) return;
    if (isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isFa
              ? 'برای تست پینگ، ابتدا اتصال را قطع کنید'
              : 'Disconnect before running a ping test'),
        ),
      );
      return;
    }

    setState(() {
      isPinging = true;
      _pingDone = 0;
      _pingTotal = configList.length;
      _testingNow.clear();
    });

    // Re-sort + rebuild on a timer instead of after every single result.
    // With ~400 items, sorting/rebuilding on every completion would be
    // both slow and would spam the native side; every 300ms keeps it
    // feeling live (results appear per-row as soon as they land, since
    // each worker also calls setState on completion) without hammering
    // the UI thread with constant full re-sorts.
    _sortTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      setState(() => configList.sort(_compareByDelay));
    });

    final queue = List<ConfigModel>.from(configList);
    int nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= queue.length) return;
        final item = queue[nextIndex++];

        if (mounted) setState(() => _testingNow.add(item.rawConfig));

        try {
          final fullConfig = getFullConfig(item.rawConfig);
          if (fullConfig == null) {
            item.delay = 0;
          } else {
            final delay = await v2ray
                .getServerDelay(config: fullConfig)
                .timeout(const Duration(seconds: 6), onTimeout: () => -1);
            item.delay = delay > 0 ? delay : 0;
          }
        } catch (_) {
          item.delay = 0;
        }

        _pingDone++;
        if (mounted) {
          setState(() => _testingNow.remove(item.rawConfig));
        }
        // Small breathing room between tests on this worker so we don't
        // fire requests at the native core back-to-back.
        await Future.delayed(const Duration(milliseconds: 70));
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
          _testingNow.clear();
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

    // Debounce: block overlapping calls and rapid repeated taps. Spamming
    // start/stop back to back was the main cause of the native core
    // getting stuck and refusing to connect until the app was restarted.
    if (_connecting) return;
    final now = DateTime.now();
    if (_lastToggleTime != null &&
        now.difference(_lastToggleTime!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastToggleTime = now;

    if (isPinging) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isFa
              ? 'لطفا تا پایان تست پینگ صبر کنید'
              : 'Please wait for the ping test to finish'),
        ),
      );
      return;
    }

    setState(() => _connecting = true);

    if (isConnected) {
      try {
        await v2ray.stopV2Ray();
        if (mounted) setState(() => isConnected = false);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isFa ? 'خطا در قطع اتصال: $e' : 'Stop error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _connecting = false);
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
        orElse: () => ConfigModel(
          rawConfig: selectedConfigRaw!,
          name: 'v2source',
          displayName: 'v2source',
          flag: '🌐',
        ),
      );

      await v2ray.startV2Ray(
        remark: current.name,
        config: fullConfig,
        proxyOnly: false,
      );
    } catch (e) {
      // Defensively reset the native side so the next attempt isn't
      // starting from a half-connected state.
      try {
        await v2ray.stopV2Ray();
      } catch (_) {}
      if (mounted) {
        setState(() => isConnected = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isFa ? 'خطا در اتصال: $e' : 'Start error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _openTelegram() async {
    try {
      await launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isFa ? 'باز کردن تلگرام ناموفق بود' : 'Could not open Telegram')),
        );
      }
    }
  }

  Widget _buildCountryStrip(bool isFa) {
    if (_countryOrder.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _countryOrder.length,
        itemBuilder: (context, index) {
          final flag = _countryOrder[index];
          final count = _countryCounts[flag] ?? 0;
          final label = countryLabel(flag, isFa);
          final selected = flag == _selectedCountry;
          return GestureDetector(
            onTap: () => setState(() => _selectedCountry = flag),
            child: Container(
              width: 64,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.blueAccent.withOpacity(0.2)
                    : Theme.of(context).cardColor,
                border: Border.all(
                  color: selected ? Colors.blueAccent : Colors.grey.withOpacity(0.3),
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.blueAccent : Colors.grey,
                    ),
                  ),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _buildSubtitle(ConfigModel item, bool isFa) {
    if (_testingNow.contains(item.rawConfig)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
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
          color: item.delay < 250 ? Colors.green : Colors.orange,
          fontSize: 12,
        ),
      );
    }
    if (item.delay == 0) {
      return Text(
        isFa ? 'بدون پاسخ' : 'Timeout',
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }
    return null;
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
                onPressed: (isPinging || _connecting) ? null : toggleConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : Colors.green,
                  disabledBackgroundColor:
                      (isConnected ? Colors.red : Colors.green).withOpacity(0.5),
                  minimumSize: const Size(125, 125),
                  shape: const CircleBorder(),
                ),
                child: _connecting
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        isConnected ? (isFa ? 'قطع' : 'STOP') : (isFa ? 'شروع' : 'START'),
                        style: const TextStyle(
                            fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
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
                          final isSelected = item.rawConfig == selectedConfigRaw;
                          return Card(
                            color: isSelected ? Colors.blue.withOpacity(0.25) : null,
                            child: ListTile(
                              leading: Text(item.flag, style: const TextStyle(fontSize: 28)),
                              title: Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: _buildSubtitle(item, isFa),
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
