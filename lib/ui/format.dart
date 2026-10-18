import 'package:intl/intl.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');
final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
final _timeFormat = DateFormat('HH:mm');
final _longDateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

String formatDate(DateTime? date) => date == null ? '—' : _dateFormat.format(date);

String formatLongDate(DateTime date) {
  final label = _longDateFormat.format(date);
  return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
}

String formatTime(DateTime? date) => date == null ? '—' : _timeFormat.format(date);

/// Formate une chaîne ISO (UTC ou locale) pour l'affichage local.
String formatIso(String? iso, {bool withTime = true, bool asUtc = false}) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = asUtc ? parsed.toUtc() : parsed.toLocal();
  return withTime ? _dateTimeFormat.format(local) : _dateFormat.format(local);
}

/// « il y a 3 min », utile pour les derniers scans.
String relativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inSeconds < 60) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return 'il y a ${diff.inDays} j';
}
