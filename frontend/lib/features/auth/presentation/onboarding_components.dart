import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../shared/widgets/flow_press_feedback.dart';

class OnboardingChoice extends StatelessWidget {
  const OnboardingChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    const blue = Color(0xFF297AE9);
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      label: label,
      child: FlowPressFeedback(
        enabled: onTap != null,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: (selected ? blue : Colors.black).withValues(
                  alpha: selected ? .12 : (dark ? .16 : .045),
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [
                            Colors.white.withValues(alpha: selected ? .19 : .1),
                            blue.withValues(alpha: selected ? .16 : .035),
                          ]
                        : [
                            Colors.white.withValues(alpha: .85),
                            (selected ? const Color(0xFFD9EAFF) : Colors.white)
                                .withValues(alpha: .5),
                          ],
                  ),
                  border: Border.all(
                    color: selected
                        ? blue.withValues(alpha: .8)
                        : Colors.white.withValues(alpha: dark ? .2 : .95),
                    width: 1.2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 40, height: 40, child: icon),
                              const Spacer(),
                              AnimatedOpacity(
                                opacity: selected ? 1 : .35,
                                duration: reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                child: Icon(
                                  selected
                                      ? LucideIcons.circle_check
                                      : LucideIcons.circle,
                                  size: 18,
                                  color: selected
                                      ? blue
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ExcludeSemantics(
                            child: Text(
                              label,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF182026), Color(0xFF20201F), Color(0xFF181B24)]
              : const [Color(0xFFEDF7FA), Color(0xFFFFF5EF), Color(0xFFF0F3FC)],
          stops: const [0, .5, 1],
        ),
      ),
    );
  }
}
