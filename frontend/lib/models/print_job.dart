class PrintJob {
  final String id;
  final String userId;
  final String userName; // who sent it
  final String fileName; // which file
  final int pages;
  final DateTime submittedAt;
  final String status; // Held | Released | Printed | Failed
  final String? failureReason;

  const PrintJob({
    required this.id,
    required this.userId,
    required this.userName,
    required this.fileName,
    required this.pages,
    required this.submittedAt,
    required this.status,
    this.failureReason,
  });

  bool get isHeld => status == 'Held';
  bool get isFailed => status == 'Failed';
  bool get isPrinted => status == 'Printed' || status == 'Released';

  /// Lower-case file extension without the dot, or '' when there is none.
  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  PrintJob copyWith({String? status, String? failureReason}) => PrintJob(
        id: id,
        userId: userId,
        userName: userName,
        fileName: fileName,
        pages: pages,
        submittedAt: submittedAt,
        status: status ?? this.status,
        failureReason: failureReason ?? this.failureReason,
      );

  factory PrintJob.fromJson(Map<String, dynamic> j) {
    return PrintJob(
      id: j['id'] as String,
      userId: j['userId'] as String,
      userName: j['userName'] as String,
      fileName: j['fileName'] as String,
      pages: (j['pages'] as num).toInt(),
      submittedAt: DateTime.parse(j['submittedAt'] as String),
      status: j['status'] as String,
      failureReason: j['failureReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'fileName': fileName,
        'pages': pages,
        'submittedAt': submittedAt.toIso8601String(),
        'status': status,
        if (failureReason != null) 'failureReason': failureReason,
      };
}
