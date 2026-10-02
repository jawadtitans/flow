import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../domain/settings_repository.dart';

class FlowProPage extends ConsumerStatefulWidget {
  const FlowProPage({super.key});
  @override
  ConsumerState<FlowProPage> createState() => _FlowProPageState();
}

class _FlowProPageState extends ConsumerState<FlowProPage> {
  SubscriptionTier tier = SubscriptionTier.pro;
  BillingPeriod period = BillingPeriod.yearly;
  bool busy = false;
  String? message;
  BillingOutcome? outcome;
  Future<void> action(Future<BillingOutcome> Function() call) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await call();
      if (mounted) {
        final c = AppLocalizations.of(context)!;
        setState(() {
          outcome = result;
          message = switch (result) {
            BillingOutcome.pending => c.purchasePending,
            BillingOutcome.restoreRequired => c.restoreRequired,
            BillingOutcome.success => c.purchaseConfirmed,
            BillingOutcome.cancelled => null,
          };
        });
      }
      ref.invalidate(subscriptionProvider);
    } catch (e) {
      if (mounted) setState(() => message = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? const Color(0xFF7FD6E0) : const Color(0xFF087E87);
    final ink = dark ? const Color(0xFFC9EFF5) : const Color(0xFF272D2D);
    final state = ref.watch(subscriptionProvider);
    final data = state.asData?.value;
    final billing = ref.watch(subscriptionBillingProvider);
    final active = data != null && data.tier != SubscriptionTier.free;
    final price = data?.prices
        .where((p) => p.tier == tier && p.period == period)
        .firstOrNull;
    final surface = theme.brightness == Brightness.dark
        ? const Color(0xFF141C21)
        : const Color(0xFFFCFBF8);
    return Scaffold(
      backgroundColor: surface,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null)
                Text(
                  message!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    backgroundColor: ink,
                    foregroundColor: surface,
                  ),
                  onPressed:
                      busy ||
                          (outcome == BillingOutcome.pending && !active) ||
                          !billing.available ||
                          (!active && price == null)
                      ? null
                      : () => action(
                          active
                              ? billing.manage
                              : () => billing.purchase(price!),
                        ),
                  child: busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          active
                              ? copy.managePlan
                              : tier == SubscriptionTier.pro
                              ? copy.getPro
                              : copy.getMax,
                        ),
                ),
              ),
              TextButton(
                onPressed: busy || !billing.available
                    ? null
                    : () => action(billing.restore),
                child: Text(copy.restorePurchases),
              ),
            ],
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1),
            radius: 1,
            colors: [
              Color.alphaBlend(accent.withValues(alpha: .065), surface),
              surface,
            ],
            stops: const [0, .75],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton.filledTonal(
                          tooltip: copy.close,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: theme.colorScheme.surface,
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/settings'),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        copy.proHeadline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'FlowEditorial',
                          fontSize: 43,
                          height: 1.17,
                          letterSpacing: -1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const _FeatureMarquee(),
                      const SizedBox(height: 28),
                      _TierSelector(
                        tier: tier,
                        onChanged: (value) => setState(() => tier = value),
                      ),
                      const SizedBox(height: 24),
                      if (active)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Flow ${data.tier.name.toUpperCase()} · ${copy.active}',
                          ),
                        ),
                      state.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => Column(
                          children: [
                            Text(
                              copy.plansUnavailable,
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(subscriptionProvider),
                              child: Text(copy.retry),
                            ),
                          ],
                        ),
                        data: (plan) => AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          child: Container(
                            key: ValueKey(tier),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(copy.feature)),
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        copy.free,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        tier == SubscriptionTier.pro
                                            ? 'Pro'
                                            : 'Max',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: accent),
                                      ),
                                    ),
                                  ],
                                ),
                                if (plan.features.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Text(copy.featuresUnavailable),
                                  ),
                                for (final feature in plan.features)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Semantics(
                                      label:
                                          '${feature.title}, ${copy.free}: ${feature.included(SubscriptionTier.free) ? copy.included : copy.notIncluded}, ${tier.name}: ${feature.included(tier) ? copy.included : copy.notIncluded}',
                                      child: ExcludeSemantics(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(feature.title),
                                            ),
                                            for (final t in [
                                              SubscriptionTier.free,
                                              tier,
                                            ])
                                              SizedBox(
                                                width: 48,
                                                child: Icon(
                                                  feature.included(t)
                                                      ? Icons.check
                                                      : Icons.remove,
                                                  color: feature.included(t)
                                                      ? (t ==
                                                                SubscriptionTier
                                                                    .free
                                                            ? theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant
                                                            : accent)
                                                      : theme.disabledColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in BillingPeriod.values)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.only(
                                  end: p == BillingPeriod.monthly ? 6 : 0,
                                  start: p == BillingPeriod.yearly ? 6 : 0,
                                ),
                                child: Semantics(
                                  key: ValueKey('billing-${p.name}'),
                                  selected: period == p,
                                  button: true,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => setState(() => period = p),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: period == p
                                            ? accent.withValues(alpha: .04)
                                            : null,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: period == p
                                              ? accent
                                              : theme.dividerColor,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment:
                                                AlignmentDirectional.topEnd,
                                            child: Icon(
                                              period == p
                                                  ? Icons.check_circle
                                                  : Icons.circle_outlined,
                                              size: 22,
                                            ),
                                          ),
                                          Text(
                                            p == BillingPeriod.monthly
                                                ? copy.monthly
                                                : copy.yearly,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            data?.prices
                                                    .where(
                                                      (v) =>
                                                          v.tier == tier &&
                                                          v.period == p,
                                                    )
                                                    .firstOrNull
                                                    ?.label ??
                                                copy.unavailable,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!billing.available)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            copy.billingUnavailable,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierSelector extends StatelessWidget {
  const _TierSelector({required this.tier, required this.onChanged});
  final SubscriptionTier tier;
  final ValueChanged<SubscriptionTier> onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = theme.brightness == Brightness.dark
        ? const Color(0xFFA5DDE6)
        : const Color(0xFF272D2D);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.onSurface.withValues(alpha: .025),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AnimatedAlign(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: tier == SubscriptionTier.pro
                    ? AlignmentDirectional.centerStart
                    : AlignmentDirectional.centerEnd,
                child: FractionallySizedBox(
                  widthFactor: .5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected,
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final value in [
                  SubscriptionTier.pro,
                  SubscriptionTier.max,
                ])
                  Expanded(
                    child: Semantics(
                      selected: value == tier,
                      button: true,
                      inMutuallyExclusiveGroup: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => onChanged(value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Text(
                            value == SubscriptionTier.pro ? 'Pro' : 'Max',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: value == tier
                                  ? theme.colorScheme.surface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureMarquee extends StatefulWidget {
  const _FeatureMarquee();
  @override
  State<_FeatureMarquee> createState() => _FeatureMarqueeState();
}

class _FeatureMarqueeState extends State<_FeatureMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 32),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
    } else {
      animation.repeat();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final labels = [
      copy.flowAi,
      copy.smartActions,
      copy.voice,
      copy.automations,
      copy.documents,
    ];
    // One measured duplicate group is translated by its own width, so text
    // scaling and localization cannot cause a gap at the loop boundary.
    final scale = MediaQuery.textScalerOf(context);
    final style = Theme.of(context).textTheme.bodyLarge!;
    var width = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scale,
      )..layout();
      width += painter.width + 64;
    }
    Widget group() => SizedBox(
      width: width,
      child: Row(
        children: [
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(label, style: style),
                ],
              ),
            ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: ClipRect(
        child: SizedBox(
          height: 38 * scale.scale(1),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Transform.translate(
                offset: Offset(-width * animation.value, 0),
                child: child,
              ),
              child: Row(children: [group(), group(), group()]),
            ),
          ),
        ),
      ),
    );
  }
}
