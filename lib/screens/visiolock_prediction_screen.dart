import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/visiolock_providers.dart';
import 'visiolock_results_screen.dart';

class VisiolockPredictionScreen extends ConsumerWidget {
  static const routeName = '/visiolock/prediction';

  const VisiolockPredictionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visiolockControllerProvider);
    final controller = ref.read(visiolockControllerProvider.notifier);

    // AI Reasoning Logic (visual simulation for UX)
    String reasoning = "Waiting for channel analysis...";
    IconData reasoningIcon = Icons.analytics_outlined;
    Color reasoningColor = Colors.grey;

    if (state.prediction != null && state.channelState != null) {
      final snr = state.channelState!.snrDb;
      if (snr < 10) {
        reasoning = "Critical SNR detected ($snr dB). \nAI prioritized Maximum Reliability over Speed.";
        reasoningIcon = Icons.shield;
        reasoningColor = Colors.orange;
      } else if (snr > 25) {
        reasoning = "Excellent channel ($snr dB). \nAI selected High-Speed Modulation.";
        reasoningIcon = Icons.rocket_launch;
        reasoningColor = Colors.green;
      } else {
        reasoning = "Moderate channel ($snr dB). \nAI balanced Speed and Error Correction.";
        reasoningIcon = Icons.balance;
        reasoningColor = Colors.blue;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('VisioLock++ AI Core')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader(context, "AI Strategy Inference"),
            const SizedBox(height: 16),
            
            // 1. Action Button (Only show if no prediction yet, or to re-run)
            if (state.prediction == null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.psychology, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "Neural Network Ready",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "The Adaptive Engine will analyze channel conditions and file properties to select the optimal transmission strategy.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: state.isBusy ? null : controller.runPrediction,
                        icon: state.isBusy 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.play_arrow),
                        label: Text(state.isBusy ? 'Processing...' : 'Run Neural Inference'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Prediction Results (Show only after prediction)
            if (state.prediction != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(reasoningIcon, color: reasoningColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Optimal Strategy Selected",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: reasoningColor
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildStrategyRow(context, "Encryption", state.prediction!.encodingLabel, Icons.lock),
                      const SizedBox(height: 12),
                      _buildStrategyRow(context, "Error Correction", state.prediction!.codingLabel, Icons.build),
                      const SizedBox(height: 12),
                      _buildStrategyRow(context, "Modulation", state.prediction!.modulationLabel, Icons.show_chart),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Explainable AI (XAI) Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: reasoningColor.withValues(alpha: 0.1),
                  border: Border.all(color: reasoningColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("AI Reasoning", style: TextStyle(fontWeight: FontWeight.bold, color: reasoningColor)),
                          const SizedBox(height: 4),
                          Text(reasoning, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (state.error != null) 
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Error: ${state.error}",
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
            
            const Spacer(),
            
            // 4. Transform Action Button (Predict -> Transmit)
            if (state.prediction != null)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: state.isBusy 
                      ? null 
                      : () async {
                          // Run simulation
                          await controller.runTransmissionSimulation();
                          
                          // Check for errors before navigating
                          // We check the NEW state
                          final newState = ref.read(visiolockControllerProvider);
                          if (newState.error == null && context.mounted) {
                            Navigator.pushNamed(context, VisiolockResultsScreen.routeName);
                          } else if (context.mounted && newState.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Transmission failed: ${newState.error}')),
                            );
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: state.isBusy
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send),
                          SizedBox(width: 12),
                          Text('INITIATE SECURE TRANSMISSION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey)),
        const Divider(),
      ],
    );
  }

  Widget _buildStrategyRow(BuildContext context, String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
