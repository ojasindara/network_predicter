import 'package:flutter/material.dart';
import '../data/db.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareState();
}

class _CompareState extends State<CompareScreen> {
  final _db = AppDB();
  List<Map<String, dynamic>> _rows = [];
  bool _sortBySpeed = true;

  Future<void> _load() async {
    final data = await _db.regionAverages();
    _rows = data;
    if (!_sortBySpeed) {
      _rows.sort((a, b) {
        final asig = (a['avg_signal_dbm'] as num?) ?? -9999;
        final bsig = (b['avg_signal_dbm'] as num?) ?? -9999;
        return bsig.compareTo(asig);
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare regions'),
        actions: [
          TextButton(
            onPressed: () { _sortBySpeed = true; _load(); },
            child: const Text('Sort by speed', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () { _sortBySpeed = false; _load(); },
            child: const Text('Sort by signal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = _rows[i];
          final name = r['name'] as String;
          final samples = r['samples'] as int? ?? 0;
          final avgSig = r['avg_signal_dbm'] == null ? '--' : (r['avg_signal_dbm'] as num).toStringAsFixed(0);
          final avgSpd = r['avg_download_mbps'] == null ? '--' : (r['avg_download_mbps'] as num).toStringAsFixed(2);
          return ListTile(
            leading: CircleAvatar(child: Text('${i+1}')),
            title: Text(name),
            subtitle: Text('Samples: $samples'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Avg speed: $avgSpd Mbps'),
                Text('Avg signal: $avgSig dBm'),
              ],
            ),
          );
        },
      ),
    );
  }
}
