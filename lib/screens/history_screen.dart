// Flutter core
import 'package:flutter/material.dart';
// Hive & model
import '../models/network_log.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Box<NetworkLog> logBox;

  @override
  void initState() {
    super.initState();
    // Open the Hive box
    logBox = Hive.box<NetworkLog>('networkLogs');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Network Log History"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ValueListenableBuilder(
        valueListenable: logBox.listenable(),
        builder: (context, Box<NetworkLog> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text("No logs recorded yet."),
            );
          }

          // Show logs in reverse (latest first)
          final logs = box.values.toList().reversed.toList();

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];

              // Format the timestamp nicely
              String formattedTime = "";
              try {
                DateTime dt = DateTime.parse(log.timestamp.toString());
                formattedTime = DateFormat("dd MMM yyyy, hh:mm a").format(dt);
              } catch (_) {
                formattedTime = log.timestamp.toString();
              }

              return ListTile(
                leading: const Icon(Icons.wifi),
                title: Text(
                  log.region.isNotEmpty
                      ? log.region
                      : "Lat: ${log.latitude.toStringAsFixed(4)}, "
                      "Lng: ${log.longitude.toStringAsFixed(4)}",
                ),
                subtitle: Text(
                  "Signal: ${log.signalStrength} | "
                      "DL: ${log.downloadSpeed.toStringAsFixed(2)} Mbps | "
                      "UL: ${log.uploadSpeed.toStringAsFixed(2)} Mbps | "
                      "Time: $formattedTime",
                ),
              );
            },
          );
        },
      ),
    );
  }
}
