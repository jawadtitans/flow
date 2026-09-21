import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../features/tasks/task_controller.dart';
import '../../../shared/widgets/flow_components.dart';

Future<void> showAgentComposer(BuildContext context) async {
  await showFlowSheet<void>(
    context: context,
    builder: (_) => const _AgentComposer(),
  );
}

class _AgentComposer extends ConsumerStatefulWidget {
  const _AgentComposer();

  @override
  ConsumerState<_AgentComposer> createState() => _AgentComposerState();
}

class _AgentComposerState extends ConsumerState<_AgentComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(top: 10, bottom: bottom),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height - 10 - bottom,
            child: Stack(
              children: [
                const FlowPageSoftEdges(topHeight: 92, bottomHeight: 108),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Row(
                        children: [
                          FlowHeaderActionSurface(
                            child: FlowIconButton(
                              icon: LucideIcons.x,
                              onPressed: () => Navigator.pop(context),
                              size: 42,
                              iconSize: 19,
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'New chat',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          FlowHeaderActionSurface(
                            child: FlowIconButton(
                              icon: LucideIcons.rotate_ccw_clock,
                              onPressed: () {},
                              size: 42,
                              iconSize: 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white12
                              : FlowColors.surface,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white12
                                : FlowColors.line,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x13000000),
                              blurRadius: 26,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Ask Flow to automate a task...',
                                    hintStyle: TextStyle(
                                      color: FlowColors.muted,
                                    ),
                                  ),
                                  onSubmitted: (_) => _save(),
                                ),
                              ),
                              FlowIconButton(
                                icon: LucideIcons.arrow_up,
                                onPressed: _save,
                                semanticLabel: 'Create task',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    ref.read(taskControllerProvider.notifier).add(_controller.text);
    if (_controller.text.trim().isNotEmpty) Navigator.pop(context);
  }
}
