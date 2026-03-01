import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_localizations.dart';
import 'translation.dart';
import '../services/ml_service.dart';

class HistoryScreen extends StatefulWidget {
  final String appLanguage;
  const HistoryScreen({super.key, this.appLanguage = 'en'});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MLService _mlService = MLService();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(widget.appLanguage);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (authSnapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)),
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

        // User is logged in — show Firestore stream
        return StreamBuilder<QuerySnapshot>(
          stream: _mlService.getHistoryStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                    const SizedBox(height: 12),
                    Text(loc['errorLoadingHistory'] ?? 'Error loading history'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => setState(() {}),
                      child: Text(loc['retry'] ?? 'Retry'),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)),
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
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final createdAt = data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.now();
                final when = DateFormat.yMMMd().add_jm().format(createdAt);

                final translation = Translation(
                  id: doc.id,
                  sourceLang: data['sourceLanguage'] ?? 'en',
                  targetLang: data['targetLanguage'] ?? 'en',
                  title:
                      '${(data['sourceLanguage'] ?? 'en').toString().toUpperCase()} → ${(data['targetLanguage'] ?? 'en').toString().toUpperCase()}',
                  snippet: data['translatedText'] ?? '',
                  imageUrl: data['imageUrl'] ?? '',
                  originalText: data['originalText'] ?? '',
                );

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TranslationDetailPage(
                          translation: translation,
                          appLanguage: widget.appLanguage,
                          isFromHistory: true,
                          onDeleteFromHistory: () => _mlService.deleteHistoryItem(doc.id),
                        ),
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
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: _buildImage(data['imageUrl']),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${data['sourceLanguage'] ?? 'en'} → ${data['targetLanguage'] ?? 'en'} • $when',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  data['translatedText'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          // Action column — delete only, card tap handles navigation
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
                                  content: Text(loc['removeFromHistoryContent'] ?? ''),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text(loc['cancel'] ?? 'Cancel')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(loc['remove'] ?? 'Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await _mlService.deleteHistoryItem(doc.id);
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
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildImage(dynamic imageUrl) {
    if (imageUrl == null || imageUrl.toString().isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image, size: 32),
      );
    }

    final url = imageUrl.toString();
    if (url.startsWith('http')) {
      return Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, size: 32),
              ));
    }
    try {
      final file = File(url);
      if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    } catch (_) {}
    return Container(color: Colors.grey.shade200, child: const Icon(Icons.image, size: 32));
  }
}