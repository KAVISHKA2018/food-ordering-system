/// Normalizes table numbers so 3, 03, and 003 are treated as the same table.
/// Purely numeric input is padded to 2 digits (3 -> "03"). Non-numeric table
/// names (e.g. "Patio-A") are trimmed but otherwise left as typed.
String normalizeTableNumber(String input) {
  final trimmed = input.trim();
  final asInt = int.tryParse(trimmed);
  if (asInt != null) {
    return asInt.toString().padLeft(2, '0');
  }
  return trimmed;
}