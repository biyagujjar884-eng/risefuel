import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_text_styles.dart';
import '../../data/models/quote_model.dart';
import '../../viewmodel/quotes_controller.dart';
import '../widgets/favorite_button.dart';
import '../widgets/quote_card.dart';
import 'about_screen.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuotesController>(
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_titleForIndex(_selectedIndex)),
            actions: <Widget>[
              if (_selectedIndex == 0)
                IconButton(
                  tooltip: controller.isAutoRotateEnabled
                      ? 'Disable Stories Mode'
                      : 'Enable Stories Mode',
                  onPressed: controller.toggleAutoRotate,
                  icon: Icon(
                    controller.isAutoRotateEnabled
                        ? Icons.auto_mode
                        : Icons.play_circle_outline,
                    color: controller.isAutoRotateEnabled
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              IconButton(
                tooltip: _themeTooltip(controller.themeMode),
                onPressed: controller.toggleThemeMode,
                icon: Icon(_themeIcon(controller.themeMode)),
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildBody(_selectedIndex),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                label: 'Home',
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
              ),
              NavigationDestination(
                label: 'Favorites',
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
              ),
              NavigationDestination(
                label: 'About',
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(int index) {
    const pages = <Widget>[
      _DailyQuoteView(),
      FavoritesScreen(),
      AboutScreen(),
    ];
    final safeIndex = index.clamp(0, pages.length - 1);
    return pages[safeIndex];
  }

  String _titleForIndex(int index) {
    const titles = <String>['Daily Quotes', 'Favorites', 'About'];
    final safeIndex = index.clamp(0, titles.length - 1);
    return titles[safeIndex];
  }

  IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.light => Icons.light_mode,
        ThemeMode.system => Icons.brightness_auto,
      };

  String _themeTooltip(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Switch to light mode',
        ThemeMode.light => 'Use dark mode',
        ThemeMode.system => 'Toggle theme',
      };
}

class _DailyQuoteView extends StatelessWidget {
  const _DailyQuoteView();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuotesController>(
      builder: (controller) {
        final quotes = controller.quotes;

        if (controller.isLoading && quotes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (quotes.isEmpty) {
          final message = controller.error ??
              'No quotes available right now. Pull down to try again.';
          return _ErrorState(
            message: message,
            onRetry: () => controller.fetchLatestQuotes(force: true),
          );
        }

        final quoteOfDay = controller.quoteOfDay;
        final currentQuote = controller.currentQuote;
        final lastUpdated = controller.lastUpdated;

        return RefreshIndicator(
          onRefresh: () => controller.fetchLatestQuotes(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: <Widget>[
              if (lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Last updated: ${_formatTime(lastUpdated)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              if (quoteOfDay != null) ...<Widget>[
                _QuoteOfDaySection(
                  quote: quoteOfDay,
                  dateLabel: controller.dateHelper.formatFriendly(DateTime.now()),
                ),
                const SizedBox(height: 28),
              ],
              Text(
                'Explore Wisdom',
                style: AppTextStyles.sectionTitle(context).copyWith(
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 380,
                child: _QuoteCarousel(quotes: quotes),
              ),
              const SizedBox(height: 16),
              _QuotePagerStatus(
                currentIndex: controller.currentIndex,
                total: quotes.length,
              ),
              const SizedBox(height: 24),
              if (currentQuote != null) _QuoteActions(quote: currentQuote),
              if (controller.error != null) ...<Widget>[
                const SizedBox(height: 18),
                _InlineWarning(message: controller.error!),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _QuoteCarousel extends StatefulWidget {
  const _QuoteCarousel({required this.quotes});

  final List<QuoteModel> quotes;

  @override
  State<_QuoteCarousel> createState() => _QuoteCarouselState();
}

class _QuoteCarouselState extends State<_QuoteCarousel> {
  late PageController _controller;
  late int _lastItemCount;

  @override
  void initState() {
    super.initState();
    final initialPage = Get.find<QuotesController>().currentIndex;
    _controller = PageController(initialPage: initialPage);
    _lastItemCount = widget.quotes.length;
  }

  @override
  void didUpdateWidget(covariant _QuoteCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = Get.find<QuotesController>();
    if (widget.quotes.isEmpty) {
      _controller.dispose();
      _controller = PageController(initialPage: 0);
      _lastItemCount = 0;
      return;
    }
    final targetPage =
        controller.currentIndex.clamp(0, widget.quotes.length - 1);
    if (widget.quotes.length != _lastItemCount) {
      _controller.dispose();
      _controller = PageController(initialPage: targetPage);
      _lastItemCount = widget.quotes.length;
    } else if (_controller.hasClients) {
      final currentPage = _controller.page?.round() ?? _controller.initialPage;
      if (currentPage != targetPage) {
        _controller.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      onPageChanged: Get.find<QuotesController>().setCurrentIndex,
      itemCount: widget.quotes.length,
      itemBuilder: (context, index) => QuoteCard(quote: widget.quotes[index]),
    );
  }
}

class _QuotePagerStatus extends StatelessWidget {
  const _QuotePagerStatus({
    required this.currentIndex,
    required this.total,
  });

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Quote ${currentIndex + 1} of $total',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _QuoteOfDaySection extends StatelessWidget {
  const _QuoteOfDaySection({
    required this.quote,
    required this.dateLabel,
  });

  final QuoteModel quote;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Quote of the Day',
              style: AppTextStyles.sectionTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '"${quote.text}"',
              textAlign: TextAlign.center,
              style: AppTextStyles.quote(context),
            ),
            const SizedBox(height: 12),
            Text(
              '— ${quote.author}',
              textAlign: TextAlign.right,
              style: AppTextStyles.author(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteActions extends StatelessWidget {
  const _QuoteActions({required this.quote});

  final QuoteModel quote;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<QuotesController>(
      builder: (controller) {
        final isFavorite = controller.isFavorite(quote);

        return Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: 'Previous quote',
                  onPressed: controller.canGoPrevious
                      ? controller.goToPreviousQuote
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 4),
                FavoriteButton(
                  isFavorite: isFavorite,
                  onPressed: () => controller.toggleFavorite(quote),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Share quote',
                  onPressed: () => _shareQuote(quote),
                  icon: const Icon(Icons.share),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Next quote',
                  onPressed:
                      controller.canGoNext ? controller.goToNextQuote : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _shareQuote(QuoteModel quote) {
    final text = '"${quote.text}" — ${quote.author}';
    Share.share(text, subject: 'Daily Quote');
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body(context).copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.sentiment_dissatisfied_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onRetry!(),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
