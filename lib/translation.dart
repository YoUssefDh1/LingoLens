import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class Translation {
  final String id;
  final String sourceLang;
  final String targetLang;
  final String title;
  final String snippet;
  final String imageUrl;
  final String originalText;
  final String languageCode;
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
  }) =>
      Translation(
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
  final String id;
  final Translation translation;
  final DateTime when;
  HistoryEntry({required this.id, required this.translation, required this.when});
}

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

class TranslationRepository extends ChangeNotifier {
  final List<Translation> _items = [];
  final List<HistoryEntry> _history = [];

  List<Translation> get translations => List.unmodifiable(_items);
  List<HistoryEntry> get history => List.unmodifiable(_history.reversed.toList());

  void addTranslation(Translation t) {
    _items.insert(0, t);
    _history.add(HistoryEntry(
      id: '${t.id}_${DateTime.now().microsecondsSinceEpoch}',
      translation: t,
      when: DateTime.now(),
    ));
    notifyListeners();
  }

  void deleteTranslation(String id) {
    _items.removeWhere((e) => e.id == id);
    _history.removeWhere((h) => h.translation.id == id);
    notifyListeners();
  }

  void toggleSave(String id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i].isSaved = !_items[i].isSaved;
    notifyListeners();
  }

  void updateNotes(String id, String notes) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i].notes = notes;
    for (final h in _history) {
      if (h.translation.id == id) h.translation.notes = notes;
    }
    notifyListeners();
  }

  Future<void> shareTranslation(String id) async {
    final t = _items.firstWhere((e) => e.id == id,
        orElse: () => throw Exception('Not found'));
    await Clipboard.setData(ClipboardData(
        text: '${t.sourceLang} → ${t.targetLang}\n${t.title}\n${t.snippet}'));
    notifyListeners();
  }

  void deleteHistoryEntry(String historyEntryId) {
    _history.removeWhere((h) => h.id == historyEntryId);
    notifyListeners();
  }
}

final TranslationRepository translationRepo = TranslationRepository();

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PAGE
// ─────────────────────────────────────────────────────────────────────────────

class TranslationDetailPage extends StatefulWidget {
  final Translation translation;
  final String appLanguage;

  const TranslationDetailPage({
    super.key,
    required this.translation,
    this.appLanguage = 'en',
  });

  @override
  State<TranslationDetailPage> createState() => _TranslationDetailPageState();
}

class _TranslationDetailPageState extends State<TranslationDetailPage> {
  late Translation _t;

  @override
  void initState() {
    super.initState();
    _t = widget.translation;
    translationRepo.addListener(_onRepo);
  }

  void _onRepo() {
    final updated = translationRepo.translations.where((e) => e.id == _t.id).firstOrNull;
    if (updated != null && mounted) setState(() => _t = updated);
  }

  @override
  void dispose() {
    translationRepo.removeListener(_onRepo);
    super.dispose();
  }

  void _openNotesEditor(Map<String, String> loc) {
    final controller = TextEditingController(text: _t.notes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(loc['notes'] ?? 'Notes',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                autofocus: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: loc['noNotesYet'] ?? 'Add notes…',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  translationRepo.updateNotes(_t.id, controller.text.trim());
                  Navigator.pop(ctx);
                },
                child: Text(loc['saveNotes'] ?? 'Save Notes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(widget.appLanguage);

    Widget imageWidget;
    final img = _t.imageUrl;
    if (img.startsWith('http')) {
      imageWidget = Image.network(img, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200));
    } else {
      try {
        final file = File(img);
        imageWidget = file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 48));
      } catch (_) {
        imageWidget = Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 48));
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_t.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: loc['close'] ?? 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: imageWidget,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lang badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_t.sourceLang}  →  ${_t.targetLang}',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer)),
                  ),
                  const SizedBox(height: 20),

                  // Original
                  _SectionLabel(icon: Icons.text_fields,
                      label: loc['originalText'] ?? 'Original Text',
                      color: theme.colorScheme.secondary),
                  const SizedBox(height: 8),
                  _TextBox(
                      text: _t.originalText.isNotEmpty ? _t.originalText : loc['notAvailable'] ?? '(not available)',
                      isDark: isDark),
                  const SizedBox(height: 20),

                  // Translated
                  _SectionLabel(icon: Icons.translate,
                      label: loc['translatedText'] ?? 'Translated Text',
                      color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  _TextBox(
                      text: _t.snippet.isNotEmpty ? _t.snippet : loc['notAvailable'] ?? '(not available)',
                      isDark: isDark),
                  const SizedBox(height: 20),

                  // Notes
                  Row(children: [
                    _SectionLabel(icon: Icons.sticky_note_2_outlined,
                        label: loc['notes'] ?? 'Notes',
                        color: Colors.orange.shade700),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openNotesEditor(loc),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(loc['edit'] ?? 'Edit'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _TextBox(
                    text: _t.notes.isNotEmpty ? _t.notes : loc['noNotesYet'] ?? 'No notes yet.',
                    isDark: isDark,
                    muted: _t.notes.isEmpty,
                  ),
                  const SizedBox(height: 32),

                  // Buttons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (!await _ensureLoggedIn(context, loc)) return;
                          translationRepo.toggleSave(_t.id);
                        },
                        icon: Icon(_t.isSaved ? Icons.favorite : Icons.favorite_border,
                            color: _t.isSaved ? Colors.red : null),
                        label: Text(_t.isSaved ? loc['saved'] ?? 'Saved' : loc['save'] ?? 'Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await translationRepo.shareTranslation(_t.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(loc['copiedToClipboard'] ?? 'Copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(loc['copy'] ?? 'Copy'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(loc['deleteTranslationTitle'] ?? 'Delete translation?'),
                            content: Text(loc['deleteTranslationContent'] ?? ''),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(loc['cancel'] ?? 'Cancel')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(loc['delete'] ?? 'Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          translationRepo.deleteTranslation(_t.id);
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(loc['deleteTranslationTitle'] ?? 'Delete Translation'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureLoggedIn(BuildContext context, Map<String, String> loc) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('loggedIn') ?? false) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc['createProfileTitle'] ?? 'Create a profile'),
        content: Text(loc['createProfileContent'] ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc['notNow'] ?? 'Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc['createProfile'] ?? 'Create profile')),
        ],
      ),
    );
    if (go == true && context.mounted) Navigator.pushNamed(context, '/signup');
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
    ]);
  }
}

class _TextBox extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool muted;
  const _TextBox({required this.text, required this.isDark, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
      ),
      child: Text(text,
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color: muted ? (isDark ? Colors.grey.shade500 : Colors.grey.shade400) : null,
            fontStyle: muted ? FontStyle.italic : FontStyle.normal,
          )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEARNING FEED
// ─────────────────────────────────────────────────────────────────────────────

class LearningFeed extends StatefulWidget {
  final String appLanguage;
  const LearningFeed({super.key, this.appLanguage = 'en'});

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
    final loc = AppLocalizations.of(widget.appLanguage);
    final items = translationRepo.translations;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_camera, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(loc['noTranslationsYet'] ?? 'No translations yet',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(loc['noTranslationsHint'] ?? 'Use the SCAN tab to capture text.'),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemBuilder: (context, index) =>
          _TranslationCard(translation: items[index], appLanguage: widget.appLanguage),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSLATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TranslationCard extends StatelessWidget {
  final Translation translation;
  final String appLanguage;
  const _TranslationCard({required this.translation, this.appLanguage = 'en'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(appLanguage);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => TranslationDetailPage(translation: translation, appLanguage: appLanguage),
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(aspectRatio: 16 / 9, child: _buildImage(translation.imageUrl)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text('${translation.sourceLang} → ${translation.targetLang}',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Icon(translation.isSaved ? Icons.favorite : Icons.favorite_border,
                      size: 18, color: translation.isSaved ? Colors.red : Colors.grey),
                ]),
                const SizedBox(height: 8),
                Text(translation.snippet,
                    style: theme.textTheme.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                if (translation.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('📝 ${translation.notes}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic, color: Colors.orange.shade700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: translation.isSaved ? loc['saved'] : loc['save'],
                    icon: Icon(translation.isSaved ? Icons.favorite : Icons.favorite_border,
                        color: translation.isSaved ? const Color(0xFF006B6B) : null),
                    onPressed: () async {
                      if (!await _ensureLoggedIn(context, loc)) return;
                      translationRepo.toggleSave(translation.id);
                    },
                  ),
                  IconButton(
                    tooltip: loc['notes'],
                    icon: const Icon(Icons.sticky_note_2_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TranslationDetailPage(translation: translation, appLanguage: appLanguage),
                    )),
                  ),
                  IconButton(
                    tooltip: loc['copy'],
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () async {
                      await translationRepo.shareTranslation(translation.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(loc['copiedToClipboard'] ?? 'Copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                  ),
                  IconButton(
                    tooltip: loc['delete'],
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(loc['deleteTranslationTitle'] ?? 'Delete?'),
                          content: Text(loc['deleteTranslationContent'] ?? ''),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false),
                                child: Text(loc['cancel'] ?? 'Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(loc['delete'] ?? 'Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        translationRepo.deleteTranslation(translation.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(loc['deleted'] ?? 'Deleted'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String img) {
    if (img.startsWith('http')) {
      return Image.network(img, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 48)));
    }
    try {
      final file = File(img);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    } catch (_) {}
    return Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 48));
  }

  Future<bool> _ensureLoggedIn(BuildContext context, Map<String, String> loc) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('loggedIn') ?? false) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc['createProfileTitle'] ?? 'Create a profile'),
        content: Text(loc['createProfileContent'] ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc['notNow'] ?? 'Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc['createProfile'] ?? 'Create profile')),
        ],
      ),
    );
    if (go == true && context.mounted) Navigator.pushNamed(context, '/signup');
    return false;
  }
}