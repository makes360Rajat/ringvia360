class SimConfig {
  final String slotId;
  final String label;
  final String carrier;
  final String phoneNumber;
  final bool isTracked;
  final bool isCorporate;

  const SimConfig({
    required this.slotId,
    required this.label,
    required this.carrier,
    required this.phoneNumber,
    required this.isTracked,
    required this.isCorporate,
  });
}

class WorkHoursSchedule {
  final bool isEnforced;
  final int startHour; // e.g. 8 for 8:30 AM
  final int startMinute;
  final int endHour;   // e.g. 18 for 6:30 PM
  final int endMinute;
  final List<int> activeDays; // 1 = Mon, 5 = Fri

  const WorkHoursSchedule({
    this.isEnforced = true,
    this.startHour = 8,
    this.startMinute = 30,
    this.endHour = 18,
    this.endMinute = 30,
    this.activeDays = const [1, 2, 3, 4, 5],
  });

  bool isCurrentlyActive() {
    if (!isEnforced) return true;
    final now = DateTime.now();
    if (!activeDays.contains(now.weekday)) return false;

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }
}
