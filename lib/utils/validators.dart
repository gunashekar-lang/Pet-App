/// Reusable form validators. Each returns `null` when valid, or a human
/// readable error message when invalid.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Indian mobile numbers: 10 digits starting with 6, 7, 8 or 9.
  static final RegExp _indianPhone = RegExp(r'^[6-9]\d{9}$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 3) return 'Enter at least 3 characters';
    return null;
  }

  /// Strips spaces, dashes, brackets and a leading +91 / 0 country prefix so
  /// the remaining digits can be checked.
  static String normalizeIndianPhone(String? value) {
    var v = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (v.startsWith('+91')) v = v.substring(3);
    if (v.startsWith('91') && v.length > 10) v = v.substring(2);
    if (v.startsWith('0') && v.length > 10) v = v.substring(1);
    return v;
  }

  static String? phone(String? value) {
    final v = normalizeIndianPhone(value);
    if (v.isEmpty) return 'Phone number is required';
    if (v.length != 10) return 'Enter a 10-digit mobile number';
    if (!_indianPhone.hasMatch(v)) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  /// True when [value] looks like an email address rather than a phone number.
  static bool looksLikeEmail(String value) => _email.hasMatch(value.trim());

  /// Sign-in accepts either an email address or an Indian mobile number.
  static String? emailOrPhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email or mobile number';

    if (_email.hasMatch(v)) return null;
    if (_indianPhone.hasMatch(normalizeIndianPhone(v))) return null;

    // Point at whichever format the entry is closest to.
    final digits = normalizeIndianPhone(v);
    if (digits.isNotEmpty && RegExp(r'^\d+$').hasMatch(digits)) {
      if (digits.length != 10) return 'Enter a 10-digit mobile number';
      return 'Enter a valid Indian mobile number';
    }
    return 'Enter a valid email address or 10-digit mobile number';
  }

  static String? price(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Price is required';
    final parsed = double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Price must be greater than 0';
    if (parsed > 1000000) return 'Price looks too high';
    return null;
  }

  /// Plain positive amount, e.g. a product selling price.
  static String? positiveNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter an amount';
    final parsed = double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    return null;
  }

  /// Same as [positiveNumber] but allows an empty field.
  static String? optionalPositiveNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return positiveNumber(v);
  }

  static String? notEmpty(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }
}
