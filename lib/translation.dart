import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Translation {
  final String id;
  final String sourceLang; // e.g. FR
  final String targetLang; // e.g. EN
  final String title;
  final String snippet; // translated text snippet
  final String imageUrl; // local file path or network URL
  final String originalText; // recognized original text
  final String languageCode; // detected language code for original text
  bool isSaved;
  String notes;

    Translation({
    required this.id,
    required this.sourceLang,
    required this.targetLang,
    required this.title,
    required this.snippet,
    required this.imageUrl,
    this.originalText = '',
    this.languageCode = '',
    this.isSaved = false,
    this.notes = '',
  });

  Translation copyWith({
    bool? isSaved,
    String? notes,
    String? originalText,
    String? languageCode,
  }) => Translation(
        id: id,
        sourceLang: sourceLang,
        targetLang: targetLang,
        title: title,
        snippet: snippet,
        imageUrl: imageUrl,
        originalText: originalText ?? this.originalText,
        languageCode: languageCode ?? this.languageCode,
        isSaved: isSaved ?? this.isSaved,
        notes: notes ?? this.notes,
      );
}

class HistoryEntry {
  final Translation translation;
  final DateTime when;

  HistoryEntry({required this.translation, required this.when});
}

class TranslationRepository extends ChangeNotifier {
  // start empty — user will add translations via camera/scanner
  final List<Translation> _items = <Translation>[];

  final List<HistoryEntry> _history = [];

  List<Translation> get translations => List.unmodifiable(_items);
  List<HistoryEntry> get history => List.unmodifiable(_history.reversed);

  void toggleSave(String id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i].isSaved = !_items[i].isSaved;
    // when user saves (favorites) add to history so it appears in History
    if (_items[i].isSaved) {
      addHistoryFromTranslation(_items[i]);
    } else {
      // if un-saving, remove history entries for this item
      _history.removeWhere((h) => h.translation.id == id);
    }
    notifyListeners();
  }

  void deleteTranslation(String id) {
    _items.removeWhere((e) => e.id == id);
    _history.removeWhere((h) => h.translation.id == id);
    notifyListeners();
  }

  void addTranslation(Translation t) {
    _items.insert(0, t);
    notifyListeners();
  }

  void updateNotes(String id, String notes) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i].notes = notes;
    notifyListeners();
  }

  Future<void> shareTranslation(String id) async {
    final t = _items.firstWhere((e) => e.id == id, orElse: () => throw Exception('Not found'));
    // For portability, copy content to clipboard and add to history
    final payload = '${t.sourceLang} → ${t.targetLang}\n${t.title}\n${t.snippet}';
    await Clipboard.setData(ClipboardData(text: payload));
    _history.add(HistoryEntry(translation: t.copyWith(), when: DateTime.now()));
    notifyListeners();
  }

  void addHistoryFromTranslation(Translation t) {
    _history.add(HistoryEntry(translation: t.copyWith(), when: DateTime.now()));
    notifyListeners();
  }
}

final TranslationRepository translationRepo = TranslationRepository();

class LearningFeed extends StatefulWidget {
  const LearningFeed({Key? key}) : super(key: key);

  @override
  State<LearningFeed> createState() => _LearningFeedState();
}

class _LearningFeedState extends State<LearningFeed> {
  @override
  void initState() {
    super.initState();
    translationRepo.addListener(_repoChanged);
  }

  void _repoChanged() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    translationRepo.removeListener(_repoChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = translationRepo.translations;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text('No translations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Use the SCAN tab to capture text with your camera.'),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemBuilder: (context, index) {
        final t = items[index];
        return _TranslationCard(translation: t);
      },
    );
  }
}

class _TranslationCard extends StatelessWidget {
  final Translation translation;

  const _TranslationCard({required this.translation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Builder(builder: (ctx) {
                final img = translation.imageUrl;
                if (img.startsWith('http')) {
                  return Image.network(img, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 48)));
                }
                try {
                  final file = File(img);
                  if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
                } catch (e) {
                  // fallthrough to placeholder
                }
                return Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 48));
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${translation.sourceLang} → ${translation.targetLang}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Text(translation.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(translation.snippet, style: theme.textTheme.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(translation.isSaved ? Icons.favorite : Icons.favorite_border, color: translation.isSaved ? const Color(0xFF006B6B) : null),
                  onPressed: () => translationRepo.toggleSave(translation.id),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => _showNotesEditor(context),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () async {
                    await translationRepo.shareTranslation(translation.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard / added to history')));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete translation?'),
                        content: const Text('This will remove the translation and any matching history.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      translationRepo.deleteTranslation(translation.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNotesEditor(BuildContext context) {
    final controller = TextEditingController(text: translation.notes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Notes', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Add study notes or context...'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        translationRepo.updateNotes(translation.id, controller.text.trim());
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
