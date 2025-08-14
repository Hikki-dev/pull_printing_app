class PrintJob {
  final String id;
  final String userId;
  final String userName;      // who sent it
  final String fileName;      // which file
  final int pages;
  final DateTime submittedAt;
  final String status;        // Held | Released | Printed | Failed

  const PrintJob({
    required this.id,
    required this.userId,
    required this.userName,
    required this.fileName,
    required this.pages,
    required this.submittedAt,
    required this.status,
  });

  factory PrintJob.fromJson(Map<String, dynamic> j) {
    return PrintJob(
      id: j['id'] as String,
      userId: j['userId'] as String,
      userName: j['userName'] as String,
      fileName: j['fileName'] as String,
      pages: (j['pages'] as num).toInt(),
      submittedAt: DateTime.parse(j['submittedAt'] as String),
      status: j['status'] as String,
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
  };
}
