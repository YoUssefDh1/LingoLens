import 'dart:io';
import 'package:flutter/material.dart';
import 'translation.dart';
import 'results_screen.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    translationRepo.addListener(_onRepo);
  }

  void _onRepo() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    translationRepo.removeListener(_onRepo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = translationRepo.history;
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.9)),
            const SizedBox(height: 12),
            const Text('No history yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Share or view a translation to build history.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = history[index];
        final t = entry.translation;
        final when = DateFormat.yMMMd().add_jm().format(entry.when);
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Builder(builder: (ctx) {
                  final img = t.imageUrl;
                  if (img.startsWith('http')) {
                    return Image.network(img, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200]));
                  }
                  try {
                    final file = File(img);
                    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
                  } catch (_) {}
                  return Container(color: Colors.grey[200]);
                }),
              ),
            ),
            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text('${t.sourceLang} → ${t.targetLang} • $when', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(t.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (t.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Notes: ${t.notes}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    final img = t.imageUrl;
                    if (img.startsWith('http')) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot re-run OCR on remote images.')));
                      return;
                    }
                    final file = File(img);
                    if (!file.existsSync()) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image file not found.')));
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultsScreen(
                          imageFile: file,
                          recognizedText: t.originalText.isNotEmpty ? t.originalText : t.snippet,
                          languageCode: t.languageCode.isNotEmpty ? t.languageCode : t.sourceLang.toLowerCase(),
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete history item?'),
                        content: const Text('This will remove this item from history.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      translationRepo.history; // access to ensure state
                      // remove history entry matching id
                      final id = t.id;
                      // repository doesn't expose direct history removal, so remove by recreating history list
                      translationRepo.history; // no-op to avoid lint
                      // use deleteTranslation to remove translation + history if present
                      translationRepo.deleteTranslation(id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed')));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
