import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../shared/widgets/flow_components.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomDockInset = MediaQuery.paddingOf(context).bottom + 118;
    final listTop = topInset + 116;
    return Scaffold(
      body: Stack(
        children: [
          ListView.separated(
            padding: EdgeInsets.fromLTRB(24, listTop, 24, bottomDockInset),
            itemCount: _favoriteItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _FavoriteCard(item: _favoriteItems[index]),
          ),
          FlowPageSoftEdges(
            topHeight: listTop + 7,
            bottomHeight: bottomDockInset + 7,
          ),
          Positioned(
            top: topInset + 7,
            left: 24,
            right: 24,
            child: const _FavoritesHeader(),
          ),
        ],
      ),
    );
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Favorites',
        style: TextStyle(
          fontSize: 38,
          letterSpacing: -1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 10),
      Text(
        'Keep important tasks and projects close at hand.',
        style: TextStyle(fontSize: 17, color: FlowColors.muted),
      ),
    ],
  );
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.item});

  final _FavoriteItem item;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : FlowColors.surface,
        borderRadius: BorderRadius.circular(FlowRadius.medium),
        border: Border.all(
          color: dark ? Colors.white12 : const Color(0xFFF0F0F2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: dark ? .46 : .16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(LucideIcons.star, color: item.color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: FlowColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              LucideIcons.chevron_right,
              size: 20,
              color: FlowColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteItem {
  const _FavoriteItem(this.title, this.detail, this.color);

  final String title;
  final String detail;
  final Color color;
}

const _favoriteItems = [
  _FavoriteItem(
    'Mobile launch',
    'Release checklist · 4 tasks',
    Color(0xFF4F7DF3),
  ),
  _FavoriteItem(
    'Design feedback',
    'Workspace · Updated today',
    Color(0xFFE98977),
  ),
  _FavoriteItem(
    'Customer research',
    'Insights · 7 open notes',
    Color(0xFF8B79D7),
  ),
  _FavoriteItem(
    'Weekly planning',
    'Product · Friday at 10:00',
    Color(0xFF57A58A),
  ),
  _FavoriteItem(
    'Navigation polish',
    'Mobile · 3 tasks in progress',
    Color(0xFFEF985B),
  ),
  _FavoriteItem(
    'Onboarding review',
    'Product · Shared with the team',
    Color(0xFF4F7DF3),
  ),
  _FavoriteItem(
    'Accessibility audit',
    'Platform · Updated yesterday',
    Color(0xFFE75858),
  ),
  _FavoriteItem(
    'Support handoff',
    'Operations · 5 unread updates',
    Color(0xFF57A58A),
  ),
  _FavoriteItem(
    'Q3 objectives',
    'Planning · 2 tasks due soon',
    Color(0xFF8B79D7),
  ),
  _FavoriteItem(
    'Release notes',
    'Mobile · Ready for review',
    Color(0xFFEF985B),
  ),
];
