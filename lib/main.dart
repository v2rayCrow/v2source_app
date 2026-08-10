import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'v2source',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // تم سرمه‌ای شیک
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class ConfigItem {
  final String rawUrl;
  final String name;
  final String host;
  final int port;
  int ping;

  ConfigItem({
    required this.rawUrl,
    required this.name,
    required this.host,
    required this.port,
    this.ping = -1,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ConfigItem> configs = [];
  bool isLoading = false;
  bool isPinging = false;
  String versionString = "v1.0.0";
  
  // آدرس سابسکریپشن شما (در صورت لزوم جایگزین کنید)
  final String subUrl = "YOUR_SUBSCRIPTION_URL_HERE"; 
  static const String githubRepo = "v2rayCrow/v2source_app";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _checkForUpdates();
    _fetchConfigs();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        versionString = "v${info.version} (${info.buildNumber})";
      });
    } catch (_) {}
  }

  // چک کردن نسخه جدید از گیت‌هاب
  Future<void> _checkForUpdates() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http.get(
        Uri.parse("https://api.github.com/repos/$githubRepo/releases/latest"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestTag = data['tag_name'] ?? '';
        String releaseUrl = data['html_url'] ?? "https://github.com/$githubRepo/releases";
        String cleanLatest = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;

        if (_isVersionNewer(info.version, cleanLatest)) {
          if (mounted) {
            _showUpdateDialog(cleanLatest, releaseUrl);
          }
        }
      }
    } catch (_) {}
  }

  bool _isVersionNewer(String current, String latest) {
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < l.length; i++) {
      int curr = i < c.length ? c[i] : 0;
      if (l[i] > curr) return true;
      if (l[i] < curr) return false;
    }
    return false;
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🚀 نسخه جدید موجود است"),
        content: Text("نسخه $version منتشر شده است. آیا مایل به به‌روزرسانی هستید؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("بعداً"),
          ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text("دانلود نسخه جدید"),
          ),
        ],
      ),
    );
  }

  // دریافت و پارس کردن کانفیگ‌ها
  Future<void> _fetchConfigs() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse(subUrl));
      if (res.statusCode == 200) {
        String content = res.body;
        // اگر Base64 بود آن را باز می‌کند
        try {
          content = utf8.decode(base64.decode(content.trim()));
        } catch (_) {}

        List<String> lines = content.split(RegExp(r'[\r\n]+'));
        List<ConfigItem> parsed = [];

        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;

          // جدا کردن نام کانفیگ و رمزگشایی URL-encode برای پرچم‌ها
          String name = "V2Ray Config";
          if (line.contains("#")) {
            var parts = line.split("#");
            try {
              name = Uri.decodeComponent(parts.sublist(1).join("#"));
            } catch (_) {
              name = parts.sublist(1).join("#");
            }
          }

          // استخراج Host و Port
          String host = "";
          int port = 443;
          try {
            var uri = Uri.parse(line);
            host = uri.host;
            port = uri.port > 0 ? uri.port : 443;
          } catch (_) {}

          if (host.isNotEmpty) {
            parsed.add(ConfigItem(
              rawUrl: line,
              name: name,
              host: host,
              port: port,
            ));
          }
        }

        setState(() {
          configs = parsed;
        });

        // تست پینگ سریع پس از دریافت
        _pingAllConfigsParallel();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("خطا در دریافت کانفیگ‌ها")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // تست پینگ موازی (Parallel TCP Ping) - هم سریع و هم دقیق
  Future<void> _pingAllConfigsParallel() async {
    if (configs.isEmpty || isPinging) return;
    setState(() => isPinging = true);

    const int batchSize = 15; // اجرای ۱۵ پینگ همزمان برای سرعت بالا
    for (int i = 0; i < configs.length; i += batchSize) {
      int end = (i + batchSize < configs.length) ? i + batchSize : configs.length;
      List<Future<void>> futures = [];

      for (int j = i; j < end; j++) {
        final index = j;
        futures.add(_measureTcpPing(configs[index].host, configs[index].port).then((ping) {
          if (mounted) {
            setState(() {
              configs[index].ping = ping;
            });
          }
        }));
      }
      await Future.wait(futures);
    }

    if (mounted) setState(() => isPinging = false);
  }

  Future<int> _measureTcpPing(String host, int port) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      sw.stop();
      await socket.close();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("v2source"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: isPinging 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.speed),
            onPressed: _pingAllConfigsParallel,
            tooltip: "تست پینگ مجدد",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConfigs,
            tooltip: "به‌روزرسانی کانفیگ‌ها",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: configs.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final item = configs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: const Color(0xFF1E293B),
                        child: ListTile(
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            "${item.host}:${item.port}",
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPingBadge(item.ping),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: item.rawUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("کانفیگ کپی شد")),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // نمایش نسخه برنامه در انتهای صفحه اصلی
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "Version $versionString",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPingBadge(int ping) {
    if (ping == -1) {
      return const Text("Timeout", style: TextStyle(color: Colors.red, fontSize: 12));
    }
    Color color = Colors.green;
    if (ping > 300) color = Colors.amber;
    if (ping > 600) color = Colors.orange;

    return Text(
      "${ping}ms",
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }
}
