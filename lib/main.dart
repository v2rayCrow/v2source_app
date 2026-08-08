import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() {
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
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String subUrl =
      'https://raw.githubusercontent.com/v2rayCrow/Sub-Link-Output/main/all.txt#v2sourceALL';

  late FlutterV2ray v2ray;
  bool isConnected = false;
  bool isLoading = false;
  List<String> configList = [];
  String? selectedConfig;
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

    // به‌روزرسانی خودکار سابسکریپشن هر ۶ ساعت
    _timer = Timer.periodic(const Duration(hours: 6), (timer) {
      fetchSubscription();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

        setState(() {
          configList = lines;
          if (configList.isNotEmpty && selectedConfig == null) {
            selectedConfig = configList.first;
          }
        });
      }
    } catch (e) {
      // خطا نادیده گرفته می‌شود تا برنامه کرش نکند
    } finally {
      setState(() => isLoading = false);
    }
  }

  void toggleConnect() async {
    if (selectedConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفا ابتدا یک کانفیگ انتخاب کنید')),
      );
      return;
    }

    if (isConnected) {
      await v2ray.stopV2Ray();
    } else {
      if (await v2ray.requestPermission()) {
        await v2ray.startV2Ray(
          remark: 'v2source Service',
          config: selectedConfig!,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('v2source'),
        actions: [
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
            const SizedBox(height: 20),
            
            // دکمه اتصال / قطع بزرگ
            ElevatedButton(
              onPressed: toggleConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : Colors.green,
                minimumSize: const Size(140, 140),
                shape: const CircleBorder(),
              ),
              child: Text(
                isConnected ? 'STOP' : 'START',
                style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 25),

            const Text(
              'سرورهای دریافت شده:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: configList.length,
                itemBuilder: (context, index) {
                  final config = configList[index];
                  final isSelected = config == selectedConfig;
                  return Card(
                    color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey[900],
                    child: ListTile(
                      title: Text(
                        'سرور شماره ${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        config.length > 35 ? '${config.substring(0, 35)}...' : config,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                      onTap: () {
                        setState(() {
                          selectedConfig = config;
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
    );
  }
}
