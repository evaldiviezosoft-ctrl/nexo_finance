const limaUtcOffset = Duration(hours: 5);

/// Returns Lima's calendar fields as a local (non-UTC) [DateTime].
///
/// Dart does not provide an IANA timezone type in its core library. Rebuilding
/// the shifted value prevents consumers such as date pickers from treating a
/// Lima wall-clock value as a UTC instant.
DateTime toLimaTime(DateTime value) {
  final shifted = value.toUtc().subtract(limaUtcOffset);
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

DateTime limaMidnightUtc(int year, int month, int day) =>
    DateTime.utc(year, month, day).add(limaUtcOffset);

DateTime startOfLimaDayUtc(DateTime value) {
  final lima = toLimaTime(value);
  return limaMidnightUtc(lima.year, lima.month, lima.day);
}

DateTime startOfLimaMonthUtc(DateTime value) {
  final lima = toLimaTime(value);
  return limaMidnightUtc(lima.year, lima.month, 1);
}

DateTime startOfLimaYearUtc(DateTime value) {
  final lima = toLimaTime(value);
  return limaMidnightUtc(lima.year, 1, 1);
}
