/// Utilities to sanitize strings before passing them to Text/TextSpan.
/// This replaces any unpaired surrogate code units with the Unicode
/// replacement character (U+FFFD), preventing "not well-formed UTF-16" errors.
class StringSanitizer {
  static final RegExp _unpairedSurrogatePattern = RegExp(
    // High surrogate not followed by low surrogate OR
    r"[\uD800-\uDBFF](?![\uDC00-\uDFFF])|" // Low surrogate not preceded by high surrogate
    r"(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]",
  );

  static String sanitizeForText(String? input) {
    if (input == null || input.isEmpty) return input ?? '';
    final cleaned = input.replaceAll(_unpairedSurrogatePattern, '\uFFFD');
    return cleaned;
  }
}
