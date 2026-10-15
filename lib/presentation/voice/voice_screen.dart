import 'package:flutter/material.dart';

class VoiceScreen extends StatelessWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('ARES Ses Sistemi')),
      body: const Center(
        child: Text(
          'DİNLEYİCİ\n\nSesli komut altyapısı hazır.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.cyanAccent, fontSize: 22),
        ),
      ),
    );
  }
}
