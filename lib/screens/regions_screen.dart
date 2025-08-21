import 'package:flutter/material.dart';
import '../data/db.dart';

class RegionsScreen extends StatefulWidget {
  const RegionsScreen({super.key});
  @override
  State<RegionsScreen> createState() => _RegionsState();
}

class _RegionsState extends State<RegionsScreen> {
  final _db = AppDB();
  List<Map<String, dynamic>> _regions = [];

  Future<void> _load() async {
    _regions = await _db.allRegions();
    if (mounted) setState(() {});
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _edit(Map<String, dynamic> r) async {
    final nameCtrl = TextEditingController(text: r['name']);
    final radiusCtrl = TextEditingController(text: '${r['radius_m']}');
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit region'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GPS: ${r['latitude'].toStringAsFixed(6)}, ${r['longitude'].toStringAsFixed(6)}'),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: radiusCtrl, decoration: const InputDecoration(labelText: 'Radius (m)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (result == true) {
      await _db.updateRegion(r['id'] as int, name: nameCtrl.text.trim(), radiusM: int.tryParse(radiusCtrl.text.trim()));
      await _load();
    }
  }

  Future<void> _delete(int id) async {
    await _db.deleteRegion(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved regions')),
      body: ListView.separated(
        itemCount: _regions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = _regions[i];
          return ListTile(
            title: Text(r['name']),
            subtitle: Text('(${r['latitude'].toStringAsFixed(5)}, ${r['longitude'].toStringAsFixed(5)}) • radius ${r['radius_m']} m'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(r)),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(r['id'] as int)),
            ]),
          );
        },
      ),
    );
  }
}
