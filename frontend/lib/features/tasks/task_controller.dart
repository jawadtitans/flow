import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task.dart';

class TaskController extends Notifier<List<Task>> {
  @override
  List<Task> build() => const [
    Task(
      id: 'FLOW-101',
      title: 'Refine the Flow mobile navigation',
      priority: TaskPriority.high,
      project: 'Mobile',
    ),
    Task(
      id: 'FLOW-102',
      title: 'Review the first-run experience',
      status: TaskStatus.inProgress,
      project: 'Onboarding',
    ),
    Task(
      id: 'FLOW-103',
      title: 'Prepare weekly priorities',
      priority: TaskPriority.low,
    ),
    Task(
      id: 'FLOW-104',
      title: 'Confirm the mobile release checklist',
      status: TaskStatus.inProgress,
      priority: TaskPriority.urgent,
      project: 'Mobile',
    ),
    Task(
      id: 'FLOW-105',
      title: 'Document the new workspace navigation',
      priority: TaskPriority.medium,
      project: 'Product',
    ),
    Task(
      id: 'FLOW-106',
      title: 'Review customer feedback from this week',
      status: TaskStatus.backlog,
      priority: TaskPriority.high,
      project: 'Research',
    ),
    Task(
      id: 'FLOW-107',
      title: 'Design the empty state for favorites',
      priority: TaskPriority.medium,
      project: 'Design',
    ),
    Task(
      id: 'FLOW-108',
      title: 'Add offline sync status to the task feed',
      status: TaskStatus.inProgress,
      priority: TaskPriority.high,
      project: 'Platform',
    ),
    Task(
      id: 'FLOW-109',
      title: 'Share the release notes with the team',
      priority: TaskPriority.low,
      project: 'Operations',
    ),
    Task(
      id: 'FLOW-110',
      title: 'Audit accessibility labels for navigation',
      status: TaskStatus.backlog,
      priority: TaskPriority.medium,
      project: 'Mobile',
    ),
    Task(
      id: 'FLOW-111',
      title: 'Prepare the next planning session',
      priority: TaskPriority.high,
      project: 'Product',
    ),
    Task(
      id: 'FLOW-112',
      title: 'Triage the latest inbox updates',
      status: TaskStatus.inProgress,
      priority: TaskPriority.medium,
      project: 'Support',
    ),
  ];

  void add(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    state = [
      Task(id: 'FLOW-${100 + state.length + 1}', title: trimmed),
      ...state,
    ];
  }

  void toggle(String id) => state = [
    for (final task in state)
      task.id == id
          ? task.copyWith(
              completed: !task.completed,
              status: task.completed ? TaskStatus.todo : TaskStatus.completed,
            )
          : task,
  ];
}

final taskControllerProvider = NotifierProvider<TaskController, List<Task>>(
  TaskController.new,
);
