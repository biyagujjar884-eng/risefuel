import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_text_styles.dart';
import '../../data/models/quote_model.dart';
import '../../viewmodel/quotes_controller.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuotesController>(
      builder: (controller) {
        final favorites = controller.favoriteQuotes;

        if (favorites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.favorite_border,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: AppTextStyles.sectionTitle(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on a quote you love to keep it here for quick access.',
                    style: AppTextStyles.body(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          itemBuilder: (context, index) {
            final quote = favorites[index];
            return _FavoriteListItem(quote: quote);
          },
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemCount: favorites.length,
        );
      },
    );
  }
}

class _FavoriteListItem extends StatelessWidget {
  const _FavoriteListItem({required this.quote});

  final QuoteModel quote;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<QuotesController>();

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          quote.text,
          style: AppTextStyles.body(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '— ${quote.author}',
            style: AppTextStyles.body(context).copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: <Widget>[
            IconButton(
              tooltip: 'Share quote',
              onPressed: () => _shareQuote(quote),
              icon: const Icon(Icons.share_outlined),
            ),
            IconButton(
              tooltip: 'Remove from favorites',
              onPressed: () => controller.removeFavorite(quote),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  void _shareQuote(QuoteModel quote) {
    Share.share(
      '"${quote.text}" — ${quote.author}',
      subject: 'Quote to remember',
    );
  }
}

