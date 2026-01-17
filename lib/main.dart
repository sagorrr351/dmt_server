import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jydooivrdwtrhbuacbiu.supabase.co',
    anonKey: 'sb_publishable_KbHtqKjcXDWqNYAkMK0yZw_G7r1KvFd',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gate Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const GateScannerPage(),
    );
  }
}

class GateScannerPage extends StatefulWidget {
  const GateScannerPage({super.key});

  @override
  State<GateScannerPage> createState() => _GateScannerPageState();
}

class _GateScannerPageState extends State<GateScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController();
  final TextEditingController _inputController = TextEditingController();
  Color _bgColor = Colors.amber.shade100;
  String _statusText = '';
  bool _processing = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handleOtp(String code) async {
    if (_processing) return;
    _processing = true;

    try {
      final client = Supabase.instance.client;

      final response = await client
          .from('otps')
          .select()
          .eq('code', code)
          .limit(1)
          .execute();

      final data = response.data as List?;

      if (data != null && data.isNotEmpty) {
        // OTP exists — delete it
        await client.from('otps').delete().eq('code', code).execute();
        setState(() {
          _bgColor = Colors.green;
          _statusText = 'Gate open';
        });
      } else {
        setState(() {
          _bgColor = Colors.red;
          _statusText = "Gate can't open";
        });
      }
    } catch (e) {
      setState(() {
        _bgColor = Colors.red;
        _statusText = 'Error: ${e.toString()}';
      });
    } finally {
      // Keep color for 2 seconds then revert
      Timer(const Duration(seconds: 2), () {
        setState(() {
          _bgColor = Colors.amber.shade100;
          _statusText = '';
        });
        _processing = false;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.isNotEmpty) {
        _handleOtp(value.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _bgColor,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    allowDuplicates: false,
                    onDetect: _onDetect,
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusText.isEmpty
                            ? 'Scan QR or enter OTP'
                            : _statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Enter OTP manually',
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _handleOtp(v.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final v = _inputController.text.trim();
                      if (v.isNotEmpty) {
                        _handleOtp(v);
                      }
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
