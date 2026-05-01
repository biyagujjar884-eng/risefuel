import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/quote_model.dart';
import '../../viewmodel/quotes_controller.dart';

class QuoteCard extends StatefulWidget {
  const QuoteCard({
    super.key,
    required this.quote,
  });

  final QuoteModel quote;

  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartAnimation = CurvedAnimation(
      parent: _heartController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final controller = Get.find<QuotesController>();
    if (!controller.isFavorite(widget.quote)) {
      controller.toggleFavorite(widget.quote);
    }
    
    setState(() {
      _showHeart = true;
    });
    _heartController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _showHeart = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.primary.withValues(alpha: 0.9),
                  AppColors.secondary.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              children: <Widget>[
                const Icon(
                  Icons.format_quote,
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        widget.quote.text,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.quote(context).copyWith(
                          color: Colors.white,
                          fontSize: 24,
                          shadows: [
                            const Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '— ${widget.quote.author}',
                      style: AppTextStyles.author(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showHeart)
            ScaleTransition(
              scale: _heartAnimation,
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 100,
              ),
            ),
        ],
      ),
    );
  }
}
