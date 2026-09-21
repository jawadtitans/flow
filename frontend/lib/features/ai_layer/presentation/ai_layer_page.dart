import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../shared/widgets/flow_components.dart';

/// UI-only prototype for Flow's AI layer.
///
/// All conversation, connection, routine, and automation states are local so
/// the experience can be reviewed before an AI service or data model exists.
class AiLayerPage extends StatefulWidget {
  const AiLayerPage({super.key});

  @override
  State<AiLayerPage> createState() => _AiLayerPageState();
}

enum _AiSection { create, routines, automations }

enum _CreateState {
  firstUse,
  thinking,
  clarifying,
  review,
  queued,
  unknown,
  saved,
}

class _AiLayerPageState extends State<AiLayerPage> {
  final _requestController = TextEditingController();
  final _requestFocus = FocusNode();
  final _draftTitleController = TextEditingController(
    text: 'Send the weekly project update',
  );
  final _routineStepController = TextEditingController();

  _AiSection _section = _AiSection.create;
  _CreateState _createState = _CreateState.firstUse;
  bool _online = true;
  bool _editingDraft = false;
  bool _routineProposed = false;
  bool _routineSaved = false;
  bool _automationEnabled = true;
  bool _showAutomationConfirmation = false;
  bool _showAutomationHistory = false;
  bool _showSuggestion = true;
  int? _editingRoutineStep;
  String _submittedRequest = '';
  String _draftSchedule = 'Today · 7:00 PM';
  final _routineSteps = <_RoutineStep>[
    _RoutineStep('Review your priorities', '8:30 AM'),
    _RoutineStep('Plan the next focused task', '8:45 AM'),
    _RoutineStep('Share a short team update', '9:00 AM'),
  ];

  @override
  void initState() {
    super.initState();
    // The AI layer is a focused extension of Today, so its own composer owns
    // the bottom area instead of competing with the main navigation dock.
    flowBottomNavigationExpanded.value = false;
    flowNavigationVisible.value = false;
  }

  @override
  void dispose() {
    _requestController.dispose();
    _requestFocus.dispose();
    _draftTitleController.dispose();
    _routineStepController.dispose();
    flowNavigationVisible.value = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    const headerHeight = 58.0;
    const composerHeight = 88.0;
    final composerBottom =
        (keyboardInset > 0 ? keyboardInset : bottomInset) + 12;
    final contentTop = topInset + headerHeight + 18;
    final contentBottom = composerHeight + composerBottom + 28;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              FlowSpace.page,
              contentTop,
              FlowSpace.page,
              contentBottom,
            ),
            children: [
              _AiSectionTabs(
                selected: _section,
                onSelect: (section) => setState(() => _section = section),
              ),
              const SizedBox(height: 16),
              _ConnectionBanner(
                online: _online,
                onTogglePreview: _setConnectionPreview,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: FlowMotion.standard,
                child: KeyedSubtree(
                  key: ValueKey(_section),
                  child: switch (_section) {
                    _AiSection.create => _buildCreateSection(),
                    _AiSection.routines => _buildRoutineSection(),
                    _AiSection.automations => _buildAutomationSection(),
                  },
                ),
              ),
            ],
          ),
          FlowPageSoftEdges(
            topHeight: contentTop + 7,
            bottomHeight: contentBottom + 7,
          ),
          Positioned(
            top: topInset + 7,
            left: FlowSpace.page,
            right: FlowSpace.page,
            child: _AiHeader(onClose: () => context.go('/today')),
          ),
          Positioned(
            left: FlowSpace.page,
            right: FlowSpace.page,
            bottom: composerBottom,
            child: _AiComposer(
              controller: _requestController,
              focusNode: _requestFocus,
              online: _online,
              hintText: _composerHint,
              onSubmit: _submitRequest,
            ),
          ),
        ],
      ),
    );
  }

  String get _composerHint => switch (_section) {
    _AiSection.create =>
      _online
          ? 'Describe a task or reminder…'
          : 'Write it now — it will send when online…',
    _AiSection.routines =>
      _online
          ? 'Describe a routine you want to build…'
          : 'Describe the routine — it will wait to send…',
    _AiSection.automations =>
      _online
          ? 'Describe something you want Flow to automate…'
          : 'Describe the automation — it will wait to send…',
  };

  Widget _buildCreateSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_createState == _CreateState.firstUse) ...[
        const _SectionIntro(
          icon: LucideIcons.bot,
          title: 'Turn a thought into a plan',
          description:
              'Write naturally. Flow always shows a draft for your review before anything is saved.',
        ),
        const SizedBox(height: 12),
        _AiPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Try one of these',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PromptChip(
                    label: 'Remind me to call Ahmad at 7pm',
                    onTap: () => _usePrompt('Remind me to call Ahmad at 7pm'),
                  ),
                  _PromptChip(
                    label: 'Plan my Kabul client follow-up tomorrow',
                    onTap: () => _usePrompt(
                      'Plan my Kabul client follow-up tomorrow at 9am',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      if (_createState == _CreateState.thinking) _buildThinkingState(),
      if (_createState == _CreateState.queued) _buildQueuedState(),
      if (_createState == _CreateState.clarifying) _buildClarifyingState(),
      if (_createState == _CreateState.review) _buildDraftReview(),
      if (_createState == _CreateState.unknown) _buildUnknownState(),
      if (_createState == _CreateState.saved) _buildSavedState(),
    ],
  );

  Widget _buildThinkingState() => _AiPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Flow is preparing a draft',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '“$_submittedRequest”',
          style: const TextStyle(color: FlowColors.muted, height: 1.35),
        ),
        const SizedBox(height: 10),
        const Text(
          'Nothing has been added to your tasks yet.',
          style: TextStyle(fontSize: 13, color: FlowColors.muted),
        ),
      ],
    ),
  );

  Widget _buildQueuedState() => _AiPanel(
    emphasis: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.network, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Waiting for a connection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '“$_submittedRequest” is safe here and will be sent when Flow reconnects.',
          style: const TextStyle(height: 1.35, color: FlowColors.muted),
        ),
        const SizedBox(height: 12),
        const _StateLabel(label: 'WAITING TO SEND'),
      ],
    ),
  );

  Widget _buildClarifyingState() => _AiPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StateLabel(label: 'ONE DETAIL NEEDED'),
        const SizedBox(height: 10),
        const Text(
          'When should Flow remind you?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'I will wait for your choice instead of guessing.',
          style: TextStyle(color: FlowColors.muted, height: 1.35),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PromptChip(
              label: 'Tonight · 7:00 PM',
              onTap: _answerClarification,
            ),
            _PromptChip(
              label: 'Tomorrow · 9:00 AM',
              onTap: _answerClarification,
            ),
            _PromptChip(
              label: 'I’ll type a time',
              onTap: () => _requestFocus.requestFocus(),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildDraftReview() => _AiPanel(
    emphasis: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.bot, size: 19),
            SizedBox(width: 8),
            _StateLabel(label: 'AI DRAFT · REVIEW BEFORE SAVING'),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Task',
          style: TextStyle(fontSize: 13, color: FlowColors.muted),
        ),
        const SizedBox(height: 4),
        if (_editingDraft)
          TextField(
            controller: _draftTitleController,
            autofocus: true,
            decoration: const InputDecoration(isDense: true),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          )
        else
          Text(
            _draftTitleController.text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 14),
        const Text(
          'When',
          style: TextStyle(fontSize: 13, color: FlowColors.muted),
        ),
        const SizedBox(height: 4),
        Text(_draftSchedule, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              label: _editingDraft ? 'Done editing' : 'Edit task',
              icon: LucideIcons.square_pen,
              onPressed: () => setState(() => _editingDraft = !_editingDraft),
            ),
            _ActionButton(
              label: 'Discard',
              icon: LucideIcons.x,
              onPressed: () =>
                  setState(() => _createState = _CreateState.firstUse),
            ),
            _ActionButton(
              label: 'Add to tasks',
              icon: LucideIcons.check,
              primary: true,
              onPressed: () =>
                  setState(() => _createState = _CreateState.saved),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Text(
          'Refine this draft',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        const Text(
          'For example: “Actually make it 7pm.” It updates this same draft.',
          style: TextStyle(fontSize: 13, height: 1.35, color: FlowColors.muted),
        ),
      ],
    ),
  );

  Widget _buildUnknownState() => _AiPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.bot, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Flow needs a clearer request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Nothing was saved. Try saying what you want to do and when, in your own words.',
          style: TextStyle(height: 1.35, color: FlowColors.muted),
        ),
        const SizedBox(height: 14),
        _ActionButton(
          label: 'Try an example',
          icon: LucideIcons.rotate_ccw_clock,
          onPressed: () => _usePrompt('Remind me to call Ahmad at 7pm'),
        ),
      ],
    ),
  );

  Widget _buildSavedState() => _AiPanel(
    emphasis: true,
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.check, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added to your tasks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'The task now appears like every other task you create in Flow.',
          style: TextStyle(height: 1.35, color: FlowColors.muted),
        ),
      ],
    ),
  );

  Widget _buildRoutineSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!_routineProposed && !_routineSaved)
        const _SectionIntro(
          icon: LucideIcons.rotate_ccw_clock,
          title: 'Build a routine around a goal',
          description:
              'Describe the outcome you want. Flow will propose steps for review; every step stays editable.',
        ),
      if (_routineProposed) _buildRoutineProposal(),
      if (_routineSaved) _buildRoutineSaved(),
    ],
  );

  Widget _buildRoutineProposal() => _AiPanel(
    emphasis: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.bot, size: 19),
            SizedBox(width: 8),
            _StateLabel(label: 'PROPOSED ROUTINE · REVIEW'),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Focused morning reset',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          '3 steps · weekdays',
          style: TextStyle(color: FlowColors.muted),
        ),
        const SizedBox(height: 14),
        ...List.generate(_routineSteps.length, _buildRoutineStep),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              label: 'Regenerate',
              icon: LucideIcons.rotate_ccw_clock,
              onPressed: _regenerateRoutine,
            ),
            _ActionButton(
              label: 'Save routine',
              icon: LucideIcons.check,
              primary: true,
              onPressed: () => setState(() {
                _routineProposed = false;
                _routineSaved = true;
              }),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildRoutineStep(int index) {
    final step = _routineSteps[index];
    final editing = _editingRoutineStep == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black.withValues(alpha: .16)
              : Colors.black.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(FlowRadius.medium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FlowColors.blue.withValues(alpha: .16),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: editing
                    ? TextField(
                        controller: _routineStepController,
                        autofocus: true,
                        onSubmitted: (_) => _saveRoutineStep(index),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step.time,
                            style: const TextStyle(
                              fontSize: 13,
                              color: FlowColors.muted,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: editing ? 'Save step' : 'Edit step',
                child: GestureDetector(
                  onTap: () => editing
                      ? _saveRoutineStep(index)
                      : _editRoutineStep(index),
                  child: Icon(
                    editing ? LucideIcons.check : LucideIcons.square_pen,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Remove ${step.title}',
                child: GestureDetector(
                  onTap: () => setState(() => _routineSteps.removeAt(index)),
                  child: const Icon(LucideIcons.x, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineSaved() => _AiPanel(
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Focused morning reset',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text('3 steps · weekdays', style: TextStyle(color: FlowColors.muted)),
        SizedBox(height: 12),
        Text(
          'Saved in Routines. It now looks and behaves like every routine you built yourself.',
          style: TextStyle(height: 1.35, color: FlowColors.muted),
        ),
      ],
    ),
  );

  Widget _buildAutomationSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _AiPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StateLabel(label: 'AUTOMATION PREVIEW'),
            const SizedBox(height: 10),
            const Text(
              'When a task becomes high priority and has no due date, schedule it for Today at 9:00 AM.',
              style: TextStyle(
                fontSize: 17,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Priority planning',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _automationEnabled,
                  onChanged: (value) =>
                      setState(() => _automationEnabled = value),
                ),
              ],
            ),
            Text(
              _automationEnabled ? 'Running' : 'Paused',
              style: const TextStyle(fontSize: 13, color: FlowColors.muted),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(
                () => _showAutomationHistory = !_showAutomationHistory,
              ),
              icon: const Icon(LucideIcons.rotate_ccw_clock, size: 17),
              label: Text(
                _showAutomationHistory
                    ? 'Hide recent runs'
                    : 'View 3 recent runs',
              ),
            ),
            if (_showAutomationHistory) ...[
              const Divider(),
              const Text('Today · Scheduled “Review release notes” at 9:00 AM'),
              const SizedBox(height: 7),
              const Text(
                'Yesterday · Scheduled “Update supplier brief” at 9:00 AM',
              ),
              const SizedBox(height: 7),
              const Text(
                'Mon · Skipped “Plan launch” because it already had a date',
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (_showSuggestion)
        _buildAutomationSuggestion()
      else
        _buildSuggestionDismissed(),
      const SizedBox(height: 14),
      _buildAutomationBuilder(),
      if (_showAutomationConfirmation) ...[
        const SizedBox(height: 14),
        _buildAutomationConfirmation(),
      ],
    ],
  );

  Widget _buildAutomationSuggestion() => _AiPanel(
    emphasis: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.bot, size: 19),
            SizedBox(width: 8),
            _StateLabel(label: 'SUGGESTED FROM YOUR WORK'),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'You moved 6 high-priority tasks into Today this week.',
          style: TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Would you like Flow to prepare that step automatically when a task has no due date?',
          style: TextStyle(height: 1.35, color: FlowColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              label: 'Not now',
              icon: LucideIcons.x,
              onPressed: () => setState(() => _showSuggestion = false),
            ),
            _ActionButton(
              label: 'Create automation',
              icon: LucideIcons.check,
              primary: true,
              onPressed: () =>
                  setState(() => _showAutomationConfirmation = true),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildSuggestionDismissed() => const _AiPanel(
    child: Text(
      'Suggestion dismissed. Flow will not interrupt you about this again right now.',
      style: TextStyle(color: FlowColors.muted, height: 1.35),
    ),
  );

  Widget _buildAutomationBuilder() => _AiPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Build an automation',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const _AutomationField(
          label: 'When',
          value: 'A task becomes high priority',
        ),
        const SizedBox(height: 8),
        const _AutomationField(label: 'If', value: 'No due date · optional'),
        const SizedBox(height: 8),
        const _AutomationField(
          label: 'Then',
          value: 'Schedule it for Today at 9:00 AM',
        ),
        const SizedBox(height: 14),
        const Text(
          'Plain-language preview',
          style: TextStyle(fontSize: 13, color: FlowColors.muted),
        ),
        const SizedBox(height: 4),
        const Text(
          'When a task becomes high priority and has no due date, schedule it for Today at 9:00 AM.',
          style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        _ActionButton(
          label: 'Review automation',
          icon: LucideIcons.check,
          onPressed: () => setState(() => _showAutomationConfirmation = true),
        ),
      ],
    ),
  );

  Widget _buildAutomationConfirmation() => _AiPanel(
    emphasis: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StateLabel(label: 'CONFIRM BEFORE TURNING ON'),
        const SizedBox(height: 10),
        const Text(
          'This can update up to 12 existing tasks.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Review the affected tasks before Flow makes this larger change.',
          style: TextStyle(height: 1.35, color: FlowColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionButton(
              label: 'Cancel',
              icon: LucideIcons.x,
              onPressed: () =>
                  setState(() => _showAutomationConfirmation = false),
            ),
            _ActionButton(
              label: 'Confirm automation',
              icon: LucideIcons.check,
              primary: true,
              onPressed: () => setState(() {
                _automationEnabled = true;
                _showAutomationConfirmation = false;
              }),
            ),
          ],
        ),
      ],
    ),
  );

  void _setConnectionPreview() {
    final nextOnline = !_online;
    setState(() => _online = nextOnline);
    if (nextOnline && _createState == _CreateState.queued) {
      _startThinking();
    }
  }

  void _usePrompt(String prompt) {
    _requestController.text = prompt;
    _submitRequest();
  }

  void _submitRequest() {
    final request = _requestController.text.trim();
    if (request.isEmpty) return;
    if (_section == _AiSection.routines) {
      setState(() {
        _routineProposed = true;
        _routineSaved = false;
      });
      return;
    }
    if (_section == _AiSection.automations) {
      setState(() => _showAutomationConfirmation = true);
      return;
    }

    setState(() {
      _submittedRequest = request;
      _createState = _online ? _CreateState.thinking : _CreateState.queued;
    });
    if (_online) _resolveTaskRequest();
  }

  void _startThinking() {
    setState(() => _createState = _CreateState.thinking);
    _resolveTaskRequest();
  }

  Future<void> _resolveTaskRequest() async {
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted || !_online || _createState != _CreateState.thinking) return;
    final request = _submittedRequest.toLowerCase();
    setState(() {
      if (request.contains('???') || request.length < 4) {
        _createState = _CreateState.unknown;
      } else if (!_hasTimeDetail(request)) {
        _createState = _CreateState.clarifying;
      } else {
        _draftTitleController.text = _submittedRequest;
        _draftSchedule = 'Today · 7:00 PM';
        _createState = _CreateState.review;
      }
    });
  }

  bool _hasTimeDetail(String request) => RegExp(
    r'\b\d{1,2}(:\d{2})?\s?(am|pm)?\b|today|tomorrow|tonight|morning|evening',
  ).hasMatch(request);

  void _answerClarification() => setState(() {
    _draftTitleController.text = _submittedRequest;
    _draftSchedule = 'Tonight · 7:00 PM';
    _createState = _CreateState.review;
  });

  void _editRoutineStep(int index) => setState(() {
    _editingRoutineStep = index;
    _routineStepController.text = _routineSteps[index].title;
  });

  void _saveRoutineStep(int index) => setState(() {
    final value = _routineStepController.text.trim();
    if (value.isNotEmpty) _routineSteps[index].title = value;
    _editingRoutineStep = null;
  });

  void _regenerateRoutine() => setState(() {
    _routineSteps
      ..clear()
      ..addAll([
        _RoutineStep('Choose one meaningful outcome', '8:30 AM'),
        _RoutineStep('Block 25 minutes for it', '8:40 AM'),
        _RoutineStep('Review what is next', '9:15 AM'),
      ]);
    _editingRoutineStep = null;
  });
}

class _AiHeader extends StatelessWidget {
  const _AiHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FlowHeaderActionSurface(
        child: FlowIconButton(
          icon: LucideIcons.x,
          onPressed: onClose,
          semanticLabel: 'Exit AI layer',
          size: 42,
          iconSize: 19,
        ),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Text(
          'AI layer',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.7,
          ),
        ),
      ),
      const _StateLabel(label: 'UI PROTOTYPE'),
    ],
  );
}

class _AiSectionTabs extends StatelessWidget {
  const _AiSectionTabs({required this.selected, required this.onSelect});

  final _AiSection selected;
  final ValueChanged<_AiSection> onSelect;

  @override
  Widget build(BuildContext context) => FlowPill(
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        _sectionTab(context, _AiSection.create, 'Create'),
        _sectionTab(context, _AiSection.routines, 'Routines'),
        _sectionTab(context, _AiSection.automations, 'Automate'),
      ],
    ),
  );

  Widget _sectionTab(BuildContext context, _AiSection section, String label) {
    final selectedTab = selected == section;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selectedTab,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(section),
          child: AnimatedContainer(
            duration: FlowMotion.standard,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selectedTab
                  ? (dark
                        ? Colors.black.withValues(alpha: .34)
                        : const Color(0xFFDCDCE0))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(FlowRadius.pill),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: selectedTab ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.online,
    required this.onTogglePreview,
  });

  final bool online;
  final VoidCallback onTogglePreview;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: online
        ? 'AI connection available. Tap to preview offline state.'
        : 'AI connection unavailable. Tap to reconnect.',
    child: GestureDetector(
      onTap: onTogglePreview,
      child: _AiPanel(
        compact: true,
        child: Row(
          children: [
            Icon(online ? LucideIcons.network : LucideIcons.x, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                online
                    ? 'AI available'
                    : 'AI offline · messages will wait to send',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              online ? 'Connected' : 'Reconnect',
              style: const TextStyle(fontSize: 13, color: FlowColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AiComposer extends StatelessWidget {
  const _AiComposer({
    required this.controller,
    required this.focusNode,
    required this.online,
    required this.hintText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool online;
  final String hintText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? FlowColors.darkSurface : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .28 : .14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Icon(LucideIcons.bot, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: const TextStyle(color: FlowColors.muted),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: online ? 'Send request' : 'Queue request',
                child: GestureDetector(
                  onTap: onSubmit,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: FlowColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.arrow_up,
                      color: Colors.white,
                      size: 20,
                    ),
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

class _AiPanel extends StatelessWidget {
  const _AiPanel({
    required this.child,
    this.emphasis = false,
    this.compact = false,
  });

  final Widget child;
  final bool emphasis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? FlowColors.darkSurface : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface.withValues(alpha: dark ? .58 : .74),
        borderRadius: BorderRadius.circular(FlowRadius.large),
        border: Border.all(
          color: emphasis
              ? (dark
                    ? Colors.white.withValues(alpha: .28)
                    : FlowColors.ink.withValues(alpha: .16))
              : (dark ? Colors.white.withValues(alpha: .12) : FlowColors.line),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .22 : .09),
            blurRadius: emphasis ? 26 : 16,
            offset: Offset(0, emphasis ? 10 : 6),
          ),
        ],
      ),
      child: Padding(padding: EdgeInsets.all(compact ? 13 : 18), child: child),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => _AiPanel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FlowColors.blue.withValues(alpha: .15),
          ),
          child: Icon(icon, size: 20, color: FlowColors.blue),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(height: 1.35, color: FlowColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StateLabel extends StatelessWidget {
  const _StateLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: FlowColors.muted,
      fontSize: 11,
      letterSpacing: .6,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.black.withValues(alpha: .2)
              : Colors.black.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(FlowRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primary ? FlowColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(FlowRadius.pill),
          border: Border.all(
            color: primary
                ? FlowColors.ink
                : Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : FlowColors.line,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: primary ? Colors.white : null),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AutomationField extends StatelessWidget {
  const _AutomationField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: .16)
          : Colors.black.withValues(alpha: .035),
      borderRadius: BorderRadius.circular(FlowRadius.medium),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(color: FlowColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(LucideIcons.square_pen, size: 16),
        ],
      ),
    ),
  );
}

class _RoutineStep {
  _RoutineStep(this.title, this.time);

  String title;
  final String time;
}
