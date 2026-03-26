import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/visiolock_providers.dart';
import 'visiolock_configuration_screen.dart';
import 'history_screen.dart';

class VisiolockSenderScreen extends ConsumerWidget {
  static const routeName = '/visiolock/sender';

  const VisiolockSenderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visiolockControllerProvider);
    final controller = ref.read(visiolockControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VisioLock++ - Secure Transmission'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              Navigator.pushNamed(context, HistoryScreen.routeName);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step 1: Select files for adaptive secure transmission.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Supported: Images, Text, PDF, JSON, Binary',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            
            // File Selection Area
            Expanded(
              child: state.selectedFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file,
                            size: 64,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          const Text('No files selected yet.'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: state.isBusy ? null : controller.selectFiles,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Files'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.selectedFiles.length + 1, // +1 for the "Add" button
                      itemBuilder: (context, index) {
                        if (index == state.selectedFiles.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: OutlinedButton.icon(
                              onPressed: state.isBusy ? null : controller.selectFiles,
                              icon: const Icon(Icons.add),
                              label: const Text('Add More Files'),
                            ),
                          );
                        }

                        final file = state.selectedFiles[index];
                        final fileSizeKB = (file.fileSize / 1024).toStringAsFixed(1);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: _buildFileIcon(file.mimeType),
                            title: Text(
                              file.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$fileSizeKB KB • ${file.mimeType}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: state.isBusy
                                  ? null
                                  : () => controller.removeFile(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            if (state.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: state.selectedFiles.isEmpty || state.isBusy
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          VisiolockConfigurationScreen.routeName,
                        );
                      },
                child: state.isBusy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Next: Configure Channel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(String mimeType) {
    IconData icon;
    Color color;

    if (mimeType.startsWith('image/')) {
      icon = Icons.image;
      color = Colors.purple;
    } else if (mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (mimeType.contains('text') || mimeType.contains('json')) {
      icon = Icons.description;
      color = Colors.blue;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color),
    );
  }
}
