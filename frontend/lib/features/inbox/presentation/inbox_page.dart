import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../features/agent/presentation/agent_composer.dart';
import '../../../features/tasks/presentation/task_sheets.dart';
import '../../../shared/widgets/flow_components.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _scrollController = ScrollController();
  bool _showOptions = false;
  final _options = {
    'Show read': true,
    'Show snoozed': false,
    'Unread first': true,
    'Unread count': false,
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final listTop = topInset + 52;
    final bottomDockInset = MediaQuery.paddingOf(context).bottom + 52;
    return Scaffold(
      body: Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              24,
              listTop,
              24,
              // The viewport reaches the physical bottom edge; rows remain
              // accessible above the floating dock and gesture area.
              bottomDockInset,
            ),
            itemCount: _inboxItems.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _InboxListItem(item: _inboxItems[index]),
          ),
          FlowPageSoftEdges(
            topHeight: listTop + 7,
            bottomHeight: bottomDockInset + 7,
          ),
          Positioned(
            top: topInset + 7,
            left: 24,
            right: 24,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Inbox',
                    style: TextStyle(
                      fontSize: 26,
                      letterSpacing: -1.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                FlowHeaderActionSurface(
                  child: FlowIconButton(
                    icon: LucideIcons.sliders_horizontal,
                    onPressed: () => showTaskFilters(context),
                    size: 42,
                    iconSize: 19,
                  ),
                ),
                const SizedBox(width: 12),
                FlowHeaderActionSurface(
                  pill: true,
                  child: FlowPill(
                    padding: const EdgeInsets.all(0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FlowHeaderActionIcon(
                          icon: LucideIcons.square_pen,
                          onPressed: () => showAgentComposer(context),
                          size: 42,
                          iconSize: 19,
                        ),
                        FlowHeaderActionIcon(
                          icon: LucideIcons.ellipsis,
                          onPressed: () =>
                              setState(() => _showOptions = !_showOptions),
                          size: 42,
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showOptions)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 104,
              right: 24,
              child: _InboxOptions(
                values: _options,
                onChange: (key) =>
                    setState(() => _options[key] = !_options[key]!),
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxListItem extends StatelessWidget {
  const _InboxListItem({required this.item});

  final _InboxItem item;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? Colors.white60 : FlowColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: item.color.withValues(alpha: dark ? .5 : .16),
            child: Text(
              item.initials,
              style: TextStyle(color: item.color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: item.unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.time,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 1.3, color: muted),
                ),
              ],
            ),
          ),
          if (item.unread) ...[
            const SizedBox(width: 10),
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 7),
              decoration: const BoxDecoration(
                color: FlowColors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InboxItem {
  const _InboxItem({
    required this.initials,
    required this.title,
    required this.preview,
    required this.time,
    required this.color,
    this.unread = false,
  });

  final String initials;
  final String title;
  final String preview;
  final String time;
  final Color color;
  final bool unread;
}

const _inboxItems = [
  _InboxItem(
    initials: 'A',
    title: 'Alex Morgan mentioned you',
    preview: 'Could you review the mobile navigation interaction?',
    time: 'Now',
    color: Color(0xFF7C98DF),
    unread: true,
  ),
  _InboxItem(
    initials: 'R',
    title: 'Design review is ready',
    preview: 'Rana moved “Refine inbox states” to In review.',
    time: '12m',
    color: Color(0xFFE58A6D),
    unread: true,
  ),
  _InboxItem(
    initials: 'P',
    title: 'Project update',
    preview: 'The Flow mobile milestone is due this Friday.',
    time: '38m',
    color: Color(0xFF8FBD8B),
  ),
  _InboxItem(
    initials: 'S',
    title: 'Sara replied on API integration',
    preview: 'I have added the revised response examples.',
    time: '1h',
    color: Color(0xFFC28AD8),
  ),
  _InboxItem(
    initials: 'J',
    title: 'New task assigned',
    preview: 'Prepare the release checklist for Android.',
    time: '2h',
    color: Color(0xFFF0B35E),
    unread: true,
  ),
  _InboxItem(
    initials: 'M',
    title: 'Weekly planning notes',
    preview: 'Mina shared notes from the product planning session.',
    time: '3h',
    color: Color(0xFF66A9C9),
  ),
  _InboxItem(
    initials: 'T',
    title: 'Task completed',
    preview: 'The splash screen accessibility pass is complete.',
    time: 'Yesterday',
    color: Color(0xFF8CBDA4),
  ),
  _InboxItem(
    initials: 'L',
    title: 'Lisa invited you to a workspace',
    preview: 'Join the Product Design workspace to collaborate.',
    time: 'Yesterday',
    color: Color(0xFFDC8FAD),
  ),
  _InboxItem(
    initials: 'N',
    title: 'Reminder: stand-up notes',
    preview: 'Add blockers and next steps before tomorrow morning.',
    time: 'Mon',
    color: Color(0xFF8098DA),
  ),
  _InboxItem(
    initials: 'C',
    title: 'Comment on FLOW-104',
    preview: 'The interaction prototype is ready for another look.',
    time: 'Mon',
    color: Color(0xFF6EBFA8),
  ),
];

class _InboxOptions extends StatelessWidget {
  const _InboxOptions({required this.values, required this.onChange});
  final Map<String, bool> values;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      width: 272,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF464858)
            : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 8, 28, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Priority inbox',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const Divider(height: 1),
          ...values.entries.map(
            (entry) => InkWell(
              onTap: () => onChange(entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: entry.value
                          ? const Icon(LucideIcons.check, size: 23)
                          : null,
                    ),
                    Text(entry.key, style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
