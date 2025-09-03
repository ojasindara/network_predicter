// map_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _selectedNetwork;
  WebViewController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show dialog each time the screen opens (after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNetworkDialog();
    });
  }

  Future<void> _initOrLoadControllerForUrl(String url) async {
    final uri = Uri.parse(url);

    // If controller not yet created, create it and load the initial URL
    if (_controller == null) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) => NavigationDecision.navigate,
            onPageStarted: (s) {},
            onPageFinished: (s) {},
            onWebResourceError: (err) {
              // optional: show error
            },
          ),
        );

      // load the requested URL
      await controller.loadRequest(uri);

      if (!mounted) return;
      setState(() {
        _controller = controller;
      });
    } else {
      // If controller exists, just load the new URL
      await _controller!.loadRequest(uri);
    }
  }

  void _showNetworkDialog() async {
    final network = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select your network"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("MTN"),
                onTap: () => Navigator.pop(context, "MTN"),
              ),
              ListTile(
                title: const Text("Airtel"),
                onTap: () => Navigator.pop(context, "Airtel"),
              ),
              ListTile(
                title: const Text("Glo"),
                onTap: () => Navigator.pop(context, "Glo"),
              ),
              ListTile(
                title: const Text("9mobile"),
                onTap: () => Navigator.pop(context, "9mobile"),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (network == null) return; // user dismissed dialog

    setState(() {
      _selectedNetwork = network;
    });

    // compute url and initialize/load controller
    final String url = _selectedNetwork == "MTN"
        ? "https://coverage.mtn.ng"
        : "https://www.google.com/maps";

    await _initOrLoadControllerForUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedNetwork == null || _controller == null) {
      // either network not chosen yet or controller not ready
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Map - $_selectedNetwork"),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_find),
            tooltip: "Change Network",
            onPressed: _showNetworkDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reload",
            onPressed: () async {
              // safe reload - controller is guaranteed non-null here
              try {
                await _controller!.reload();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Reload failed: $e")),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller!),
    );
  }
}
