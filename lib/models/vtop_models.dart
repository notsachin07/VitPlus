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
  final String courseType;
  final String block;
  final bool isLab;
  final int serial;

  TimetableSlot({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.courseCode,
    required this.courseName,
    required this.venue,
    required this.faculty,
    required this.slotName,
    this.courseType = '',
    this.block = '',
    this.isLab = false,
    this.serial = 0,
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
      courseType: map['courseType'] ?? '',
      block: map['block'] ?? '',
      isLab: map['isLab'] ?? false,
      serial: map['serial'] ?? 0,
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
    'courseType': courseType,
    'block': block,
    'isLab': isLab,
    'serial': serial,
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
  final String courseId;  // For fetching detailed attendance
  final String category;
  final String debarStatus;

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
    this.courseId = '',
    this.category = '',
    this.debarStatus = '',
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
      courseId: map['courseId'] ?? '',
      category: map['category'] ?? '',
      debarStatus: map['debarStatus'] ?? '',
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
    'courseId': courseId,
    'category': category,
    'debarStatus': debarStatus,
  };
}

class AttendanceDetail {
  final String serial;
  final String date;
  final String slot;
  final String dayTime;
  final String status; // "Present" or "Absent"
  final String remark;

  AttendanceDetail({
    this.serial = '',
    required this.date,
    required this.slot,
    this.dayTime = '',
    required this.status,
    this.remark = '',
  });

  factory AttendanceDetail.fromMap(Map<String, dynamic> map) {
    return AttendanceDetail(
      serial: map['serial'] ?? '',
      date: map['date'] ?? '',
      slot: map['slot'] ?? '',
      dayTime: map['dayTime'] ?? '',
      status: map['status'] ?? '',
      remark: map['remark'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'serial': serial,
    'date': date,
    'slot': slot,
    'dayTime': dayTime,
    'status': status,
    'remark': remark,
  };
}

/// Full attendance data for a specific course
class FullAttendanceData {
  final String semesterId;
  final String courseId;
  final String courseType;
  final List<AttendanceDetail> records;
  final DateTime fetchedAt;

  FullAttendanceData({
    required this.semesterId,
    required this.courseId,
    required this.courseType,
    required this.records,
    required this.fetchedAt,
  });

  factory FullAttendanceData.fromMap(Map<String, dynamic> map) {
    return FullAttendanceData(
      semesterId: map['semesterId'] ?? '',
      courseId: map['courseId'] ?? '',
      courseType: map['courseType'] ?? '',
      records: (map['records'] as List?)
          ?.map((e) => AttendanceDetail.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      fetchedAt: DateTime.tryParse(map['fetchedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'semesterId': semesterId,
    'courseId': courseId,
    'courseType': courseType,
    'records': records.map((e) => e.toMap()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
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
  final String serial;
  final String name;
  final String maxMarks;
  final String weightage;
  final String status;
  final String scoredMarks;
  final String weightedScore;
  final String remark;

  MarkComponent({
    this.serial = '',
    required this.name,
    required this.maxMarks,
    required this.weightage,
    this.status = '',
    required this.scoredMarks,
    required this.weightedScore,
    this.remark = '',
  });

  factory MarkComponent.fromMap(Map<String, dynamic> map) {
    return MarkComponent(
      serial: map['serial'] ?? '',
      name: map['name'] ?? '',
      maxMarks: map['maxMarks'] ?? '',
      weightage: map['weightage'] ?? '',
      status: map['status'] ?? '',
      scoredMarks: map['scoredMarks'] ?? '',
      weightedScore: map['weightedScore'] ?? '',
      remark: map['remark'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'serial': serial,
    'name': name,
    'maxMarks': maxMarks,
    'weightage': weightage,
    'status': status,
    'scoredMarks': scoredMarks,
    'weightedScore': weightedScore,
    'remark': remark,
  };
  
  double get maxMarksDouble => double.tryParse(maxMarks) ?? 0.0;
  double get scoredMarksDouble => double.tryParse(scoredMarks) ?? 0.0;
  double get weightageDouble => double.tryParse(weightage) ?? 0.0;
  double get weightedScoreDouble => double.tryParse(weightedScore) ?? 0.0;
}

class CourseMarks {
  final String serial;
  final String courseCode;
  final String courseName;
  final String courseType;
  final String faculty;
  final String slot;
  final List<MarkComponent> components;

  CourseMarks({
    this.serial = '',
    required this.courseCode,
    required this.courseName,
    required this.courseType,
    this.faculty = '',
    this.slot = '',
    required this.components,
  });

  factory CourseMarks.fromMap(Map<String, dynamic> map) {
    return CourseMarks(
      serial: map['serial'] ?? '',
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      courseType: map['courseType'] ?? '',
      faculty: map['faculty'] ?? '',
      slot: map['slot'] ?? '',
      components: (map['components'] as List?)
          ?.map((e) => MarkComponent.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() => {
    'serial': serial,
    'courseCode': courseCode,
    'courseName': courseName,
    'courseType': courseType,
    'faculty': faculty,
    'slot': slot,
    'components': components.map((e) => e.toMap()).toList(),
  };
  
  double get totalWeightedScore {
    double total = 0;
    for (var c in components) {
      total += c.weightedScoreDouble;
    }
    return total;
  }
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
  final String serial;
  final String courseCode;
  final String courseName;
  final String courseType;
  final String courseId;
  final String slot;
  final String examDate;
  final String examSession;
  final String reportingTime;
  final String examTime;
  final String venue;
  final String seatLocation;
  final String seatNo;

  ExamSlot({
    this.serial = '',
    required this.courseCode,
    required this.courseName,
    this.courseType = '',
    this.courseId = '',
    this.slot = '',
    required this.examDate,
    this.examSession = '',
    this.reportingTime = '',
    required this.examTime,
    required this.venue,
    this.seatLocation = '',
    required this.seatNo,
  });

  factory ExamSlot.fromMap(Map<String, dynamic> map) {
    return ExamSlot(
      serial: map['serial'] ?? '',
      courseCode: map['courseCode'] ?? '',
      courseName: map['courseName'] ?? '',
      courseType: map['courseType'] ?? '',
      courseId: map['courseId'] ?? '',
      slot: map['slot'] ?? '',
      examDate: map['examDate'] ?? map['date'] ?? '',
      examSession: map['examSession'] ?? '',
      reportingTime: map['reportingTime'] ?? '',
      examTime: map['examTime'] ?? map['time'] ?? '',
      venue: map['venue'] ?? '',
      seatLocation: map['seatLocation'] ?? '',
      seatNo: map['seatNo'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'serial': serial,
    'courseCode': courseCode,
    'courseName': courseName,
    'courseType': courseType,
    'courseId': courseId,
    'slot': slot,
    'examDate': examDate,
    'examSession': examSession,
    'reportingTime': reportingTime,
    'examTime': examTime,
    'venue': venue,
    'seatLocation': seatLocation,
    'seatNo': seatNo,
  };
}

/// Exams grouped by exam type (CAT1, CAT2, FAT etc)
class ExamTypeGroup {
  final String examType;
  final List<ExamSlot> exams;

  ExamTypeGroup({
    required this.examType,
    required this.exams,
  });

  factory ExamTypeGroup.fromMap(Map<String, dynamic> map) {
    return ExamTypeGroup(
      examType: map['examType'] ?? '',
      exams: (map['exams'] as List?)
          ?.map((e) => ExamSlot.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() => {
    'examType': examType,
    'exams': exams.map((e) => e.toMap()).toList(),
  };
}

class ExamScheduleData {
  final String semesterId;
  final List<ExamTypeGroup> examGroups;
  final DateTime fetchedAt;

  ExamScheduleData({
    required this.semesterId,
    required this.examGroups,
    required this.fetchedAt,
  });
  
  /// Flat list of all exams
  List<ExamSlot> get allExams {
    return examGroups.expand((g) => g.exams).toList();
  }

  factory ExamScheduleData.fromMap(Map<String, dynamic> map) {
    return ExamScheduleData(
      semesterId: map['semesterId'] ?? '',
      examGroups: (map['examGroups'] as List?)
          ?.map((e) => ExamTypeGroup.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      fetchedAt: DateTime.tryParse(map['fetchedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'semesterId': semesterId,
    'examGroups': examGroups.map((e) => e.toMap()).toList(),
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
