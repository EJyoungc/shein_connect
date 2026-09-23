class Validators {
  /// Validates standard email address
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Validates a Malawian 10-digit mobile number.
  /// Standard Malawi phone numbers have 10 digits starting with 08 or 09
  /// (e.g. TNM: 088xxxxxxx, Airtel: 099xxxxxxx, 098xxxxxxx).
  /// Also normalizes "+265" or "265" prefixes if provided.
  static bool isValidMalawianMobile(String mobile) {
    final cleaned = cleanMalawianNumber(mobile);
    // Malawian numbers start with 08 or 09 followed by 8 digits (10 digits total)
    final mwRegex = RegExp(r'^0[89]\d{8}$');
    return mwRegex.hasMatch(cleaned);
  }

  /// Normalizes Malawian phone number to 10 digits starting with 0
  static String cleanMalawianNumber(String input) {
    String cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '').trim();
    if (cleaned.startsWith('+265')) {
      cleaned = '0${cleaned.substring(4)}';
    } else if (cleaned.startsWith('265')) {
      cleaned = '0${cleaned.substring(3)}';
    }
    return cleaned;
  }

  /// Validates whether the input is either a valid Email OR a 10-digit Malawian Mobile
  static String? validateLoginIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email or Malawian mobile number';
    }
    final trimmed = value.trim();

    // Check if user entered numbers or starting with 0 or +265
    final isLikelyPhone = RegExp(r'^[+0-9]').hasMatch(trimmed) && !trimmed.contains('@');

    if (isLikelyPhone) {
      if (!isValidMalawianMobile(trimmed)) {
        return 'Malawian numbers must be 10 digits (e.g. 088XXXXXXX / 099XXXXXXX)';
      }
      return null;
    } else {
      if (!isValidEmail(trimmed)) {
        return 'Please enter a valid email address';
      }
      return null;
    }
  }

  /// Validates Full Name
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Full name must be at least 2 characters';
    }
    return null;
  }

  /// Validates Malawian Mobile specifically
  static String? validateMalawianMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your mobile number';
    }
    if (!isValidMalawianMobile(value)) {
      return 'Enter a valid 10-digit Malawian number (e.g. 088XXXXXXX or 099XXXXXXX)';
    }
    return null;
  }

  /// Validates Email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates Gender selection
  static String? validateGender(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select your gender';
    }
    return null;
  }

  /// Validates Password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }
}
