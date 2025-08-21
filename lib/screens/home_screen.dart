import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data for now
    final bool isConnected = true;
    final String prediction = "Good";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Network Predictor"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status section
            Card(
              color: isConnected ? Colors.green[100] : Colors.red[100],
              child: ListTile(
                leading: Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                title: Text(
                  "Network Status: ${isConnected ? "Online" : "Offline"}",
                  style: const TextStyle(fontSize: 18),
                ),
                subtitle: Text("Predicted: $prediction"),
              ),
            ),
            const SizedBox(height: 20),

            // Map placeholder
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text("Map will display here"),
              ),
            ),
            const SizedBox(height: 20),

            // Navigation buttons
            ElevatedButton.icon(
              icon: const Icon(Icons.network_check),
              label: const Text("Log Network"),
              onPressed: () {
                Navigator.pushNamed(context, '/logger');
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text("View History"),
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text("View Map"),
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
            ),
          ],
        ),
      ),
    );
  }
}
