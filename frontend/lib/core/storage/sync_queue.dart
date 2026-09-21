/// Drift-backed implementation belongs here. Queued mutations make offline actions immediate.
class PendingMutation {
  const PendingMutation(this.method, this.path, this.body);
  final String method, path;
  final Map<String, dynamic> body;
}

abstract interface class SyncQueue {
  Future<void> enqueue(PendingMutation mutation);
  Future<List<PendingMutation>> pending();
  Future<void> acknowledge(PendingMutation mutation);
}
