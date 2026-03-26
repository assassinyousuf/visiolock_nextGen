import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/visiolock_providers.dart';
import 'visiolock_prediction_screen.dart';

class VisiolockConfigurationScreen extends ConsumerStatefulWidget {
  static const routeName = '/visiolock/configuration';

  const VisiolockConfigurationScreen({super.key});

  @override
  ConsumerState<VisiolockConfigurationScreen> createState() =>
      _VisiolockConfigurationScreenState();
}

class _VisiolockConfigurationScreenState
    extends ConsumerState<VisiolockConfigurationScreen> {
  late final TextEditingController _snrController;
  late final TextEditingController _noiseController;
  final TextEditingController _pinController = TextEditingController();
  
  double _snr = 20.0;
  double _noise = 0.2;
  bool _isListening = false;
  bool _secureMode = false;

  @override
  void initState() {
    super.initState();
    _snrController = TextEditingController(text: _snr.toStringAsFixed(1));
    _noiseController = TextEditingController(text: _noise.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _snrController.dispose();
    _noiseController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _simulateMicrophoneInput() async {
    setState(() => _isListening = true);
    
    // Simulate analyzing ambient noise for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Randomize slightly for demo effect
    // In a real app, this would be computed from Mic samples (RMS)
    final randomSnr = 12.0 + Random().nextDouble() * 15.0; // 12-27 dB
    final randomNoise = 0.1 + Random().nextDouble() * 0.3; // 0.1-0.4

    setState(() {
      _isListening = false;
      _snr = randomSnr;
      _noise = randomNoise;
      _snrController.text = _snr.toStringAsFixed(1);
      _noiseController.text = _noise.toStringAsFixed(2);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ambient noise analyzed: Updated SNR/Noise estimates.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(visiolockControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('VisioLock++ - Channel Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader(context, '1. Channel Modeling'),
            const SizedBox(height: 12),
            
            // Microphone Input Feature
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: Icon(
                  _isListening ? Icons.mic_external_on : Icons.mic,
                  color: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
                ),
                title: Text(_isListening ? 'Analyzing Environment...' : 'Auto-Detect Noise'),
                subtitle: const Text('Use microphone to estimate SNR'),
                trailing: _isListening 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : FilledButton.tonal(
                        onPressed: _simulateMicrophoneInput,
                        child: const Text('Measure'),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // SNR Sliders
            Text('Signal-to-Noise Ratio (SNR): ${_snr.toStringAsFixed(1)} dB',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(
              min: 0,
              max: 40,
              divisions: 80,
              value: _snr.clamp(0, 40),
              label: _snr.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _snr = value;
                  _snrController.text = value.toStringAsFixed(1);
                });
              },
            ),
            
            const SizedBox(height: 8),
            Text('Background Noise Level: ${_noise.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(
              min: 0,
              max: 1.0,
              divisions: 100,
              value: _noise.clamp(0, 1),
              label: _noise.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _noise = value;
                  _noiseController.text = value.toStringAsFixed(2);
                });
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(context, '2. Security Context'),
            const SizedBox(height: 12),
            
            // Security PIN
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Transmission Key (PIN/Passphrase)',
                prefixIcon: const Icon(Icons.vpn_key),
                border: const OutlineInputBorder(),
                filled: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Used for initial handshake authentication',
                  onPressed: () {},
                ),
              ),
              onChanged: (v) {
                setState(() => _secureMode = v.isNotEmpty);
              },
            ),
            
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Integrity Verification'),
              subtitle: const Text('SHA-256 Hashing after decode'),
              value: _secureMode,
              onChanged: (val) {
                if (_pinController.text.isEmpty && val) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a PIN to enable secure mode.")));
                } else {
                   setState(() => _secureMode = val);
                }
              },
            ),

            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () {
                  // Save state
                  final parsedSnr = double.tryParse(_snrController.text) ?? _snr;
                  final parsedNoise = double.tryParse(_noiseController.text) ?? _noise;
                  
                  controller.updateChannel(
                    snr: parsedSnr, 
                    noiseLevel: parsedNoise.clamp(0.0, 1.0),
                  );

                  // Navigate
                  Navigator.pushNamed(
                    context,
                    VisiolockPredictionScreen.routeName,
                  );
                },
                child: const Text('Next: Run Neural Inference'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
