import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../shared/widgets/flow_components.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomDockInset = MediaQuery.paddingOf(context).bottom + 118;
    final listTop = topInset + 92;
    return Scaffold(
      body: Stack(
        children: [
          ListView.separated(
            padding: EdgeInsets.fromLTRB(24, listTop, 24, bottomDockInset),
            itemCount: _searchDestinations.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 16)
                : const Divider(height: 1),
            itemBuilder: (context, index) => index == 0
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Teams',
                      style: TextStyle(
                        fontSize: 17,
                        color: FlowColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : _SearchDestinationRow(
                    destination: _searchDestinations[index - 1],
                  ),
          ),
          FlowPageSoftEdges(
            topHeight: listTop + 7,
            bottomHeight: bottomDockInset + 7,
          ),
          Positioned(
            top: topInset + 7,
            left: 24,
            right: 24,
            child: _SearchField(controller: _controller, focusNode: _focus),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? FlowColors.darkSurface : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .26 : .14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: .78),
                  surface.withValues(alpha: .58),
                ],
              ),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: .18)
                    : Colors.white.withValues(alpha: .78),
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: SizedBox(
              height: 54,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  const Icon(LucideIcons.search, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search workspace...',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: FlowColors.muted,
                        ),
                      ),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchDestinationRow extends StatelessWidget {
  const _SearchDestinationRow({required this.destination});

  final _SearchDestination destination;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: Row(
      children: [
        Icon(destination.icon, color: destination.color, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Text(destination.name, style: const TextStyle(fontSize: 18)),
        ),
        const Icon(
          LucideIcons.chevron_right,
          size: 20,
          color: FlowColors.muted,
        ),
      ],
    ),
  );
}

class _SearchDestination {
  const _SearchDestination(this.name, this.icon, this.color);

  final String name;
  final IconData icon;
  final Color color;
}

const _searchDestinations = [
  _SearchDestination('Personal', LucideIcons.network, FlowColors.blue),
  _SearchDestination('Mobile', LucideIcons.smartphone, Color(0xFF8B79D7)),
  _SearchDestination('Product', LucideIcons.box, Color(0xFFE98977)),
  _SearchDestination('Design', LucideIcons.palette, Color(0xFF57A58A)),
  _SearchDestination('Operations', LucideIcons.layers, Color(0xFFEF985B)),
];
