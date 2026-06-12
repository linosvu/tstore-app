class TaskCollaborator {
  const TaskCollaborator({
    required this.userId,
    required this.canEdit,
    required this.addedAt,
  });

  final String userId;
  final bool canEdit;
  final String addedAt;

  factory TaskCollaborator.fromJson(Map<String, dynamic> json) {
    return TaskCollaborator(
      userId: json['userId'] as String? ?? '',
      canEdit: json['canEdit'] as bool? ?? false,
      addedAt: json['addedAt'] as String? ?? '',
    );
  }
}

class TaskAttachment {
  const TaskAttachment({
    required this.url,
    this.mediaType,
    this.note,
    required this.createdAt,
    required this.createdByUserId,
  });

  final String url;
  final String? mediaType;
  final String? note;
  final String createdAt;
  final String createdByUserId;

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    return TaskAttachment(
      url: json['url'] as String? ?? '',
      mediaType: json['mediaType'] as String?,
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      createdByUserId: json['createdByUserId'] as String? ?? '',
    );
  }
}

class TaskNote {
  const TaskNote({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String content;
  final String createdAt;

  factory TaskNote.fromJson(Map<String, dynamic> json) {
    return TaskNote(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class TaskPublic {
  const TaskPublic({
    required this.id,
    required this.title,
    this.content,
    this.dueAt,
    required this.priority,
    required this.status,
    required this.assignedUserId,
    required this.collaborators,
    required this.attachments,
    required this.notes,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? content;
  final String? dueAt;
  final String priority;
  final String status;
  final String assignedUserId;
  final List<TaskCollaborator> collaborators;
  final List<TaskAttachment> attachments;
  final List<TaskNote> notes;
  final String createdByUserId;
  final String createdAt;
  final String updatedAt;

  bool get isOverdue {
    if (dueAt == null || dueAt!.isEmpty) return false;
    if (status != 'pending' && status != 'in_progress') return false;
    final d = DateTime.tryParse(dueAt!);
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }

  factory TaskPublic.fromJson(Map<String, dynamic> json) {
    final collabRaw = json['collaborators'];
    final attachRaw = json['attachments'];
    final notesRaw = json['notes'];
    return TaskPublic(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      dueAt: json['dueAt'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'pending',
      assignedUserId: json['assignedUserId'] as String? ?? '',
      collaborators: collabRaw is List
          ? collabRaw
              .whereType<Map<String, dynamic>>()
              .map(TaskCollaborator.fromJson)
              .toList()
          : const [],
      attachments: attachRaw is List
          ? attachRaw
              .whereType<Map<String, dynamic>>()
              .map(TaskAttachment.fromJson)
              .toList()
          : const [],
      notes: notesRaw is List
          ? notesRaw
              .whereType<Map<String, dynamic>>()
              .map(TaskNote.fromJson)
              .toList()
          : const [],
      createdByUserId: json['createdByUserId'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class TasksListResult {
  const TasksListResult({
    required this.items,
    required this.totalPages,
    required this.total,
  });

  final List<TaskPublic> items;
  final int totalPages;
  final int total;

  factory TasksListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(TaskPublic.fromJson)
            .toList()
        : <TaskPublic>[];
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final pages = (json['totalPages'] as num?)?.toInt() ??
        ((total / limit).ceil().clamp(1, 9999));
    return TasksListResult(
      items: list,
      totalPages: pages,
      total: total,
    );
  }
}
