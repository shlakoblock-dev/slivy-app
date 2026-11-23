import 'package:flutter/material.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const SlivyApp());

class SlivyApp extends StatelessWidget {
  const SlivyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slivy VPN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0418),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6A0DAD),
          secondary: Color(0xFF9B59B6),
          surface: Color(0xFF1A0B2E),
          onSurface: Color(0xFFE0D0FF),
        ),
        textTheme: GoogleFonts.pressStart2pTextTheme(),
      ),
      home: const VpnHome(),
    );
  }
}

class VpnHome extends StatefulWidget {
  const VpnHome({super.key});
  @override
  State<VpnHome> createState() => _VpnHomeState();
}

class _VpnHomeState extends State<VpnHome> {
  late final FlutterVless _vless;
  // ⚠️ ЗАМЕНИ НА СВОЮ ССЫЛКУ НА sub.txt
  final String _subUrl = 'https://raw.githubusercontent.com/ТВОЙ_НИК/ТВОЙ_РЕПО/main/sub.txt';
  List<Map<String, dynamic>> _servers = [];
  bool _loading = false;
  String _status = 'ГОТОВ';

  @override
  void initState() {
    super.initState();
    _vless = FlutterVless(
      onStatusChanged: (s) => setState(() => _status = 'VPN: ${s.state}'),
    );
  }

  Future<void> _loadAndTest() async {
    setState(() { _loading = true; _status = 'ЗАГРУЗКА...'; });
    try {
      final resp = await http.get(Uri.parse(_subUrl));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      
      final parsed = FlutterVless.parseMany(resp.body);
      final fast = <Map<String, dynamic>>[];
      int total = parsed.length;
      int checked = 0;

      setState(() => _status = 'ПИНГ 0/$total...');

      // Пингуем по одному, оставляем только те, что < 1000ms
      for (var i = 0; i < parsed.length; i++) {
        final cfg = parsed[i].getFullConfiguration();
        checked++;
        setState(() => _status = 'ПИНГ $checked/$total');
        
        if (cfg.isEmpty) continue;
        try {
          final d = await _vless.getServerDelay(config: cfg);
          // 🔥 ГЛАВНЫЙ ФИЛЬТР: только быстрые (< 1000 ms)
          if (d > 0 && d < 1000) {
            fast.add({
              'remark': parsed[i].remark.isNotEmpty ? parsed[i].remark : 'SRV ${i+1}',
              'config': cfg,
              'delay': d,
            });
          }
        } catch (_) {}
      }

      fast.sort((a, b) => (a['delay'] as int).compareTo(b['delay'] as int));
      setState(() {
        _servers = fast;
        _status = 'БЫСТРЫХ: ${fast.length} / $total';
      });
    } catch (e) {
      setState(() => _status = 'ОШИБКА: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _connect(Map<String, dynamic> s) async {
    setState(() => _status = 'ПОДКЛЮЧЕНИЕ...');
    try {
      await _vless.initializeVless(
        providerBundleIdentifier: 'com.example.slivy_vpn',
        groupIdentifier: 'group.com.example.slivy_vpn',
      );
      final ok = await _vless.requestPermission();
      if (!ok) { setState(() => _status = 'НЕТ РАЗРЕШЕНИЯ'); return; }
      await _vless.startVless(remark: s['remark'], config: s['config']);
    } catch (e) {
      setState(() => _status = 'ОШИБКА: $e');
    }
  }

  Widget _pixelBox(Widget child, {Color? border}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A0B2E),
        border: Border.all(color: border ?? const Color(0xFF9B59B6), width: 3),
      ),
      padding: const EdgeInsets.all(8),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A0DAD),
        title: Text('🍇 SLIVY VPN', style: GoogleFonts.pressStart2p(fontSize: 14)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _pixelBox(
              Text(_status, style: GoogleFonts.pressStart2p(fontSize: 9)),
              border: const Color(0xFFE0D0FF),
            ),
          ),
          if (_loading) const LinearProgressIndicator(color: Color(0xFF9B59B6)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _servers.length,
              itemBuilder: (c, i) {
                final s = _servers[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _connect(s),
                    child: _pixelBox(
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s['remark'] ?? '?',
                              style: GoogleFonts.pressStart2p(fontSize: 8),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${s['delay']}ms',
                              style: GoogleFonts.pressStart2p(
                                  fontSize: 8, color: const Color(0xFF9B59B6))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6A0DAD),
        onPressed: _loading ? null : _loadAndTest,
        child: const Icon(Icons.refresh, color: Color(0xFFE0D0FF)),
      ),
    );
  }
}
