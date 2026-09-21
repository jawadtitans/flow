enum TaskStatus { backlog, todo, inProgress, completed }

enum TaskPriority { urgent, high, medium, low }

class Task {
  const Task({
    required this.id,
    required this.title,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.project = 'Personal',
    this.completed = false,
  });

  final String id;
  final String title;
  final TaskStatus status;
  final TaskPriority priority;
  final String project;
  final bool completed;

  Task copyWith({bool? completed, TaskStatus? status}) => Task(
    id: id,
    title: title,
    status: status ?? this.status,
    priority: priority,
    project: project,
    completed: completed ?? this.completed,
  );
}
