// +-------------------------------------------------------------------------
//
//   taskmgr-rs - UI 数值格式化
//
//   文件:       flutter_app/lib/ui/formatters.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   IEC 80000-13；旧版任务管理器显示约定
// --------------------------------------------------------------------------

String unavailable(String fallback) => fallback;

String textOrUnavailable(String? value, String fallback) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}

String integerOrUnavailable(BigInt? value, String fallback) {
  return value == null ? fallback : _groupDigits(value.toString());
}

String signedIntegerOrUnavailable(Object? value, String fallback) {
  return value == null ? fallback : _groupDigits(value.toString());
}

String kibOrUnavailable(BigInt? value, String fallback) {
  return value == null ? fallback : '${_groupDigits(value.toString())} K';
}

String bytesOrUnavailable(BigInt? value, String fallback) {
  if (value == null) {
    return fallback;
  }
  final bytes = value.toDouble();
  const units = <String>['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var amount = bytes;
  var unit = 0;
  while (amount.abs() >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  return '${amount >= 100 || unit == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1)} ${units[unit]}';
}

String rateOrUnavailable(double? bytesPerSecond, String fallback) {
  if (bytesPerSecond == null || !bytesPerSecond.isFinite) {
    return fallback;
  }
  final value = BigInt.from(bytesPerSecond.round());
  return '${bytesOrUnavailable(value, fallback)}/s';
}

String linkSpeedOrUnavailable(BigInt? bitsPerSecond, String fallback) {
  if (bitsPerSecond == null) {
    return fallback;
  }
  final value = bitsPerSecond.toDouble();
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(value >= 10000000000 ? 0 : 1)} Gbps';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 100000000 ? 0 : 1)} Mbps';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)} Kbps';
  }
  return '${bitsPerSecond.toString()} bps';
}

String percentOrUnavailable(double? value, String fallback) {
  if (value == null || !value.isFinite) {
    return fallback;
  }
  return '${value.clamp(0, 100).round()}%';
}

String cpuTimeOrUnavailable(BigInt? millis, String fallback) {
  if (millis == null) {
    return fallback;
  }
  final totalSeconds = millis ~/ BigInt.from(1000);
  final seconds = (totalSeconds % BigInt.from(60)).toInt();
  final totalMinutes = totalSeconds ~/ BigInt.from(60);
  final minutes = (totalMinutes % BigInt.from(60)).toInt();
  final hours = totalMinutes ~/ BigInt.from(60);
  return '${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String idleTimeOrUnavailable(BigInt? seconds, String fallback) {
  if (seconds == null) {
    return fallback;
  }
  final duration = Duration(seconds: seconds.toInt());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '$hours:${minutes.toString().padLeft(2, '0')}';
}

String replacePrintf(String template, List<Object> values) {
  var result = template;
  for (final value in values) {
    result = result.replaceFirst(RegExp(r'%(?:u|d|s)'), value.toString());
  }
  return result.replaceAll('%%', '%');
}

String _groupDigits(String raw) {
  final negative = raw.startsWith('-');
  final digits = negative ? raw.substring(1) : raw;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return negative ? '-$buffer' : buffer.toString();
}
