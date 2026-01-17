import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// Put Supabase credentials in top-level constants so REST calls can use them.
const kSupabaseUrl = 'https://jydooivrdwtrhbuacbiu.supabase.co';
const kSupabaseAnonKey = 'sb_publishable_KbHtqKjcXDWqNYAkMK0yZw_G7r1KvFd';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
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
  QRViewController? _controller;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  final TextEditingController _inputController = TextEditingController();
  Color _bgColor = Colors.amber.shade100;
  String _statusText = '';
  bool _processing = false;

  @override
  void dispose() {
    _controller?.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    _controller!.scannedDataStream.listen((scanData) {
      for (Barcode barcode in scanData) {
        if (barcode.code != null && barcode.code!.isNotEmpty) {
          _handleOtp(barcode.code!.trim());
          break;
        }
      }
    });
  }

  Future<void> _handleOtp(String code) async {
    if (_processing) return;
    _processing = true;

    try {
      final encodedCode = Uri.encodeComponent(code);

      final getUri = Uri.parse('$kSupabaseUrl/rest/v1/payments?select=*&otp=eq.$encodedCode&limit=1');
      final headers = {
        'apikey': kSupabaseAnonKey,
        'Authorization': 'Bearer $kSupabaseAnonKey',
        'Accept': 'application/json',
      };

      final getResp = await http.get(getUri, headers: headers);
      if (getResp.statusCode == 200) {
        final body = getResp.body;
        final exists = body.trim().startsWith('[') && body.trim() != '[]';
        if (exists) {
          final deleteUri = Uri.parse('$kSupabaseUrl/rest/v1/payments?otp=eq.$encodedCode');
          final delResp = await http.delete(deleteUri, headers: {
            ...headers,
            'Prefer': 'return=minimal',
          });
          if (delResp.statusCode == 204 || delResp.statusCode == 200) {
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
        } else {
          setState(() {
            _bgColor = Colors.red;
            _statusText = "Gate can't open";
          });
        }
      } else {
        setState(() {
          _bgColor = Colors.red;
          _statusText = 'Error: ${getResp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _bgColor = Colors.red;
        _statusText = 'Error: ${e.toString()}';
      });
    } finally {
      Timer(const Duration(seconds: 2), () {
        setState(() {
          _bgColor = Colors.amber.shade100;
          _statusText = '';
        });
        _processing = false;
      });
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
            onPressed: () => _controller?.flipCamera(),
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
                  QRView(
                    key: _qrKey,
                    onQRViewCreated: _onQRViewCreated,
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
                        _statusText.isEmpty ? 'Scan QR or enter OTP' : _statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
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
