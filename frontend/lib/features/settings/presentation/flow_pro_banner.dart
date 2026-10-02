import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/settings_repository.dart';
import '../../../l10n/app_localizations.dart';

enum FlowProBannerVariant { large, compact }

class FlowProBanner extends ConsumerStatefulWidget {
  const FlowProBanner({this.variant = FlowProBannerVariant.compact, super.key});
  final FlowProBannerVariant variant;
  @override
  ConsumerState<FlowProBanner> createState() => _FlowProBannerState();
}

class _FlowProBannerState extends ConsumerState<FlowProBanner> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final large = widget.variant == FlowProBannerVariant.large;
    final plan = ref.watch(subscriptionProvider).asData?.value.tier;
    final subscribed = plan != null && plan != SubscriptionTier.free;
    return AnimatedScale(
      scale: pressed && !MediaQuery.disableAnimationsOf(context) ? .985 : 1,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: const Color(0xFF052A38),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onHighlightChanged: (v) => setState(() => pressed = v),
          onTap: () => context.push('/settings/pro'),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _PremiumLight())),
              Padding(
                padding: EdgeInsets.all(large ? 24 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan == SubscriptionTier.max ? 'flow max' : 'flow pro',
                      style: TextStyle(
                        color: const Color(0xFFF5FBFF),
                        fontSize: large ? 42 : 29,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      copy.proSubtitle,
                      style: TextStyle(
                        color: const Color(0xFFE4F3F9),
                        fontSize: large ? 16 : 13,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: large ? 62 : 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F8FA),
                          foregroundColor: const Color(0xFF082B39),
                          minimumSize: Size(0, large ? 52 : 44),
                        ),
                        onPressed: () => context.push('/settings/pro'),
                        child: Text(
                          subscribed ? copy.managePlan : copy.learnMore,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumLight extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF052631), Color(0xFF00566A), Color(0xFF071D34)],
        ).createShader(rect),
    );
    canvas.save();
    canvas.translate(size.width * .66, size.height * .5);
    canvas.rotate(-math.pi / 8);
    for (var i = 0; i < 5; i++) {
      final panel = RRect.fromRectAndRadius(
        Rect.fromLTWH((i - 2) * 38, (i.isEven ? -65 : -15), 60, 135),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        panel,
        Paint()
          ..color = const Color(0xFF60D9EF).withValues(alpha: .1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawRRect(
        panel,
        Paint()..color = const Color(0xFF89E7F5).withValues(alpha: .12),
      );
      canvas.drawRRect(
        panel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFADF1FF).withValues(alpha: .18),
      );
    }
    canvas.restore();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xAA061E2B), Color(0x00061E2B)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PremiumLight oldDelegate) => false;
}
