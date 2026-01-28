/// VTOP Data Models

class Semester {
  final String id;
  final String name;

  Semester({required this.id, required this.name});

  factory Semester.fromMap(Map<String, dynamic> map) {
    return Semester(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}

class TimetableSlot {
  final String day;
  final String startTime;
  final String endTime;
  final String courseCode;
  final String courseName;
  final String venue;
  final String faculty;
  final String slotName;

  TimetableSlot({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.courseCode,
    required this.courseName,
    required this.venue,
    required this.faculty,
    required this.slotName,
  });

  factory TimetableSlot.fromMap(Map<String, dynamic> map) {
    return TimetableSlot(
      day: map['day'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      venue: map['venue'] ?? '',
      faculty: map['faculty'] ?? '',
      slotName: map['slotName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
    'courseCode': courseCode,
    'courseName': courseName,
    'venue': venue,
    'faculty': faculty,
    'slotName': slotName,
  };
}

class TimetableData {
  final String semesterId;
  final List<TimetableSlot> slots;
  final DateTime fetchedAt;

  TimetableData({
    required this.semesterId,
    required this.slots,
    required this.fetchedAt,
  });

  factory TimetableData.fromMap(Map<String, dynamic> map) {
    return TimetableData(
      semesterId: map['semesterId'] ?? '',
      slots: (map['slots'] as List?)
          ?.map((e) => TimetableSlot.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      fetchedAt: DateTime.tryParse(map['fetchedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'semesterId': semesterId,
    'slots': slots.map((e) => e.toMap()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };
}

class AttendanceCourse {
  final String courseCode;
  final String courseName;
  final String courseType;
  final String faculty;
  final String slot;
  final int totalClasses;
  final int attendedClasses;
  final int absentClasses;
  final double percentage;

  AttendanceCourse({
    required this.courseCode,
    required this.courseName,
    required this.courseType,
    required this.faculty,
    required this.slot,
    required this.totalClasses,
    required this.attendedClasses,
    required this.absentClasses,
    required this.percentage,
  });

  factory AttendanceCourse.fromMap(Map<String, dynamic> map) {
    return AttendanceCourse(
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      courseType: map['courseType'] ?? '',
      faculty: map['faculty'] ?? '',
      slot: map['slot'] ?? '',
      totalClasses: map['totalClasses'] ?? 0,
      attendedClasses: map['attendedClasses'] ?? 0,
      absentClasses: map['absentClasses'] ?? 0,
      percentage: (map['percentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'courseCode': courseCode,
    'courseName': courseName,
    'courseType': courseType,
    'faculty': faculty,
    'slot': slot,
    'totalClasses': totalClasses,
    'attendedClasses': attendedClasses,
    'absentClasses': absentClasses,
    'percentage': percentage,
  };
}

class AttendanceDetail {
  final String date;
  final String slot;
  final String status; // "Present" or "Absent"
  final String courseCode;

  AttendanceDetail({
    required this.date,
    required this.slot,
    required this.status,
    required this.courseCode,
  });

  factory AttendanceDetail.fromMap(Map<String, dynamic> map) {
    return AttendanceDetail(
      date: map['date'] ?? '',
      slot: map['slot'] ?? '',
      status: map['status'] ?? '',
      courseCode: map['courseCode'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date,
    'slot': slot,
    'status': status,
    'courseCode': courseCode,
  };
}

class AttendanceData {
  final String semesterId;
  final List<AttendanceCourse> courses;
  final DateTime fetchedAt;

  AttendanceData({
    required this.semesterId,
    required this.courses,
    required this.fetchedAt,
  });

  factory AttendanceData.fromMap(Map<String, dynamic> map) {
    return AttendanceData(
      semesterId: map['semesterId'] ?? '',
      courses: (map['courses'] as List?)
          ?.map((e) => AttendanceCourse.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      fetchedAt: DateTime.tryParse(map['fetchedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'semesterId': semesterId,
    'courses': courses.map((e) => e.toMap()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  double get overallPercentage {
    if (courses.isEmpty) return 0;
    int totalAttended = 0;
    int totalClasses = 0;
    for (var course in courses) {
      totalAttended += course.attendedClasses;
      totalClasses += course.totalClasses;
    }
    if (totalClasses == 0) return 0;
    return (totalAttended / totalClasses) * 100;
  }
}

class MarkComponent {
  final String name;
  final double maxMarks;
  final double scoredMarks;
  final double weightage;
  final double weightedScore;

  MarkComponent({
    required this.name,
    required this.maxMarks,
    required this.scoredMarks,
    required this.weightage,
    required this.weightedScore,
  });

  factory MarkComponent.fromMap(Map<String, dynamic> map) {
    return MarkComponent(
      name: map['name'] ?? '',
      maxMarks: (map['maxMarks'] ?? 0.0).toDouble(),
      scoredMarks: (map['scoredMarks'] ?? 0.0).toDouble(),
      weightage: (map['weightage'] ?? 0.0).toDouble(),
      weightedScore: (map['weightedScore'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'maxMarks': maxMarks,
    'scoredMarks': scoredMarks,
    'weightage': weightage,
    'weightedScore': weightedScore,
  };
}

class CourseMarks {
  final String courseCode;
  final String courseName;
  final String courseType;
  final List<MarkComponent> components;
  final double totalWeightedScore;

  CourseMarks({
    required this.courseCode,
    required this.courseName,
    required this.courseType,
    required this.components,
    required this.totalWeightedScore,
  });

  factory CourseMarks.fromMap(Map<String, dynamic> map) {
    return CourseMarks(
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      courseType: map['courseType'] ?? '',
      components: (map['components'] as List?)
          ?.map((e) => MarkComponent.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      totalWeightedScore: (map['totalWeightedScore'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'courseCode': courseCode,
    'courseName': courseName,
    'courseType': courseType,
    'components': components.map((e) => e.toMap()).toList(),
    'totalWeightedScore': totalWeightedScore,
  };
}

class MarksData {
  final String semesterId;
  final List<CourseMarks> courses;
  final DateTime fetchedAt;

  MarksData({
    required this.semesterId,
    required this.courses,
    required this.fetchedAt,
  });

  factory MarksData.fromMap(Map<String, dynamic> map) {
    return MarksData(
      semesterId: map['semesterId'] ?? '',
      courses: (map['courses'] as List?)
          ?.map((e) => CourseMarks.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      fetchedAt: DateTime.tryParse(map['fetchedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'semesterId': semesterId,
    'courses': courses.map((e) => e.toMap()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };
}

class ExamSlot {
  final String courseCode;
  final String courseName;
  final String examType;
  final String date;
  final String time;
  final String venue;
  final String seatNo;
  final String slot;

  ExamSlot({
    required this.courseCode,
    required this.courseName,
    required this.examType,
    required this.date,
    required this.time,
    required this.venue,
    required this.seatNo,
    this.slot = '',
  });

  factory ExamSlot.fromMap(Map<String, dynamic> map) {
    return ExamSlot(
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      examType: map['examType'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      venue: map['venue'] ?? '',
      seatNo: map['seatNo'] ?? '',
      slot: map['slot'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'courseCode': courseCode,
    'courseName': courseName,
    'examType': examType,
    'date': date,
    'time': time,
    'venue': venue,
    'seatNo': seatNo,
    'slot': slot,
  };
}

class ExamScheduleData {
  final String semesterId;
  final List<ExamSlot> exams;
  final DateTime fetchedAt;

  ExamScheduleData({
    required this.semesterId,
    required this.exams,
    required this.fetchedAt,
  });

  factory ExamScheduleData.fromMap(Map<String, dynamic> map) {
    return ExamScheduleData(
      semesterId: map['semesterId'] ?? '',
      exams: (map['exams'] as List?)
          ?.map((e) => ExamSlot.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      fetchedAt: DateTime.tryParse(map['fetchedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'semesterId': semesterId,
    'exams': exams.map((e) => e.toMap()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };
}

class VtopSession {
  final String cookie;
  final String csrfToken;
  final String username;
  final bool isAuthenticated;
  final DateTime? expiresAt;

  VtopSession({
    required this.cookie,
    required this.csrfToken,
    required this.username,
    required this.isAuthenticated,
    this.expiresAt,
  });

  factory VtopSession.empty() {
    return VtopSession(
      cookie: '',
      csrfToken: '',
      username: '',
      isAuthenticated: false,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }
}
