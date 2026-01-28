import '../../models/vtop_models.dart';

/// Get list of day indices (1-7) that have classes
List<int> getDayList(TimetableData? data) {
  if (data == null) return [];
  
  const dayMap = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  final found = <int>{};
  for (final slot in data.slots) {
    final dayIndex = dayMap[slot.day.toLowerCase()];
    if (dayIndex != null) {
      found.add(dayIndex);
    }
  }
  
  final result = found.toList()..sort();
  return result;
}

/// Get slots for a specific day index (1-7)
List<TimetableSlot> getDaySlots(TimetableData data, int dayIndex) {
  const dayMap = {
    1: 'monday',
    2: 'tuesday',
    3: 'wednesday',
    4: 'thursday',
    5: 'friday',
    6: 'saturday',
    7: 'sunday',
  };

  final dayName = dayMap[dayIndex]!;
  return data.slots
      .where((s) => s.day.toLowerCase() == dayName)
      .toList();
}

/// Add free time slots between classes
List<TimetableSlot> addFreeSlots(List<TimetableSlot> slots) {
  if (slots.isEmpty) return slots;

  // Sort by start time first
  slots.sort((a, b) => a.startTime.compareTo(b.startTime));

  final result = <TimetableSlot>[];
  
  for (int i = 0; i < slots.length; i++) {
    // Add the class slot
    result.add(slots[i]);
    
    // Check if there's a gap before the next class
    if (i < slots.length - 1) {
      final currentEnd = _parseTime(slots[i].endTime);
      final nextStart = _parseTime(slots[i + 1].startTime);
      
      final gapMinutes = (nextStart - currentEnd).inMinutes;
      
      // Add free slot if gap is at least 15 minutes
      if (gapMinutes >= 15) {
        result.add(TimetableSlot(
          day: slots[i].day,
          startTime: slots[i].endTime,
          endTime: slots[i + 1].startTime,
          courseCode: '',
          courseName: 'Free Time',
          venue: '',
          faculty: '',
          slotName: '$gapMinutes',
          serial: -1, // Mark as free slot
        ));
      }
    }
  }
  
  return result;
}

/// Merge consecutive lab slots into one
List<TimetableSlot> mergeLabSlots(List<TimetableSlot> slots) {
  if (slots.isEmpty) return slots;

  slots.sort((a, b) => a.startTime.compareTo(b.startTime));

  final result = <TimetableSlot>[];
  TimetableSlot? currentLabSlot;

  for (final slot in slots) {
    if (!slot.isLab) {
      if (currentLabSlot != null) {
        result.add(currentLabSlot);
        currentLabSlot = null;
      }
      result.add(slot);
    } else {
      if (currentLabSlot != null &&
          currentLabSlot.courseCode == slot.courseCode) {
        // Extend the current lab slot
        currentLabSlot = TimetableSlot(
          day: currentLabSlot.day,
          startTime: currentLabSlot.startTime,
          endTime: slot.endTime,
          courseCode: currentLabSlot.courseCode,
          courseName: currentLabSlot.courseName,
          venue: currentLabSlot.venue,
          faculty: currentLabSlot.faculty,
          slotName: '${currentLabSlot.slotName}+${slot.slotName}',
          courseType: currentLabSlot.courseType,
          block: currentLabSlot.block,
          isLab: true,
          serial: currentLabSlot.serial,
        );
      } else {
        if (currentLabSlot != null) {
          result.add(currentLabSlot);
        }
        currentLabSlot = slot;
      }
    }
  }

  if (currentLabSlot != null) {
    result.add(currentLabSlot);
  }

  return result;
}

Duration _parseTime(String timeStr) {
  if (timeStr.isEmpty) return Duration.zero;
  final parts = timeStr.split(':').map((e) => int.tryParse(e) ?? 0).toList();
  if (parts.length < 2) return Duration.zero;
  return Duration(hours: parts[0], minutes: parts[1]);
}

/// Format time to 12-hour format
String formatTime12H(String time) {
  if (time.isEmpty) return '-';
  final parts = time.split(':');
  if (parts.length < 2) return time;

  int hours = int.tryParse(parts[0]) ?? 0;
  final minutes = parts[1];
  String period;

  if (hours > 12) {
    hours -= 12;
    period = 'PM';
  } else if (hours == 12) {
    period = 'PM';
  } else if (hours == 0) {
    hours = 12;
    period = 'AM';
  } else {
    period = 'AM';
  }

  return '$hours:$minutes $period';
}
