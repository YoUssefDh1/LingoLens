import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';
import 'translation.dart';

class HistoryScreen extends StatefulWidget {
  final String appLanguage;
  const HistoryScreen({super.key, this.appLanguage = 'en'});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoggedIn = false;
  bool _loginStateLoaded = false;

  @override
  void initState() {
    super.initState();
    translationRepo.addListener(_onRepo);
    _loadLoginState();
  }

  void _onRepo() => mounted ? setState(() {}) : null;

  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('loggedIn') ?? false;
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _loginStateLoaded = true;
    });
  }

  @override
  void dispose() {
    translationRepo.removeListener(_onRepo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(widget.appLanguage);

    if (!_loginStateLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.9)),
              const SizedBox(height: 12),
              Text(
                loc['createAccountHistory'] ?? 'Create an account to save history',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                loc['createAccountHint'] ?? '',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: Text(loc['goToProfile'] ?? 'Go to Profile'),
              ),
            ],
          ),
        ),
      );
    }

    final history = translationRepo.history;
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.9)),
            const SizedBox(height: 12),
            Text(loc['noHistoryYet'] ?? 'No history yet',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(loc['noHistoryHint'] ?? 'Scan and translate text to build your history.'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TranslationDetailPage(
                    translation: t, appLanguage: widget.appLanguage),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 72, height: 72, child: _buildImage(t.imageUrl)),
                  ),
                  const SizedBox(width: 12),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('${t.sourceLang} → ${t.targetLang} • $when',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text(t.snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                        if (t.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📝 ${t.notes}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic, color: Colors.orange.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Action column
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        tooltip: loc['viewDetails'] ?? 'View details',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TranslationDetailPage(
                                translation: t, appLanguage: widget.appLanguage),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        tooltip: loc['removeFromHistory'] ?? 'Remove from history',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(
                                  loc['removeFromHistoryTitle'] ?? 'Remove from history?'),
                              content:
                                  Text(loc['removeFromHistoryContent'] ?? ''),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(loc['cancel'] ?? 'Cancel')),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(loc['remove'] ?? 'Remove'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            translationRepo.deleteHistoryEntry(entry.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(loc['removed'] ?? 'Removed from history'),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(String img) {
    if (img.startsWith('http')) {
      return Image.network(img, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200));
    }
    try {
      final file = File(img);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    } catch (_) {}
    return Container(
        color: Colors.grey.shade200, child: const Icon(Icons.image, size: 32));
  }
}