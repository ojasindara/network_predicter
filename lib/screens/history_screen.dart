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
    logBox = Hive.box<NetworkLog>('networkLog');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Network Log History"),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .primary,
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
          final logs = box.values
              .toList()
              .reversed
              .toList();

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];

              // Format the timestamp safely
              String formattedTime;
              try {
                DateTime dt = DateTime.fromMillisecondsSinceEpoch(
                    log.timestamp);
                formattedTime = DateFormat("dd MMM yyyy, hh:mm a").format(dt);
              } catch (_) {
                formattedTime = log.timestamp.toString();
              }

              return ListTile(
                leading: const Icon(Icons.wifi),
                title: Text(
                  "Lat: ${(log.latitude ?? 0.0).toStringAsFixed(4)}, "
                      "Lng: ${(log.longitude ?? 0.0).toStringAsFixed(4)}",
                ),
                subtitle: Text(
                  "Signal: ${log.signalStrength ?? 0} | "
                      "DL: ${(log.downloadKb ?? 0.0).toStringAsFixed(
                      2)} Kbps | "
                      "UL: ${(log.uploadKb ?? 0.0).toStringAsFixed(2)} Kbps | "
                      "Weather: ${log.weather ?? 'Unknown'} | "
                      "Temp: ${log.temperature?.toStringAsFixed(1) ??
                      'N/A'}°C | "
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