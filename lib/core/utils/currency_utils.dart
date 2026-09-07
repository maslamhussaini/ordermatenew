// lib/core/utils/currency_utils.dart

/// Utility class for handling currency formatting
/// Currency is retrieved from the store's default currency setting
class CurrencyUtils {
  /// Format a numeric amount with the given currency code
  /// Example: formatCurrency(1234.56, 'USD') => 'USD 1,234.56'
  /// Example: formatCurrency(1234.56, 'PKR') => 'PKR 1,234.56'
  static String formatCurrency(double amount, String? currencyCode) {
    final code = currencyCode ?? 'USD'; // Default fallback
    final formattedAmount = amount.toStringAsFixed(2);

    // Add thousand separators
    final parts = formattedAmount.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    // Add commas for thousands
    final buffer = StringBuffer();
    var count = 0;
    for (var i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
      count++;
    }

    final formattedInteger = buffer.toString().split('').reversed.join();

    return '$code $formattedInteger.$decimalPart';
  }

  /// Format a numeric amount with currency symbol
  /// Common currency symbols mapping
  static String formatWithSymbol(double amount, String? currencyCode) {
    final code = currencyCode ?? 'USD';
    final symbol = _getCurrencySymbol(code);
    final formattedAmount = amount.toStringAsFixed(2);

    // Add thousand separators
    final parts = formattedAmount.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    // Add commas for thousands
    final buffer = StringBuffer();
    var count = 0;
    for (var i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
      count++;
    }

    final formattedInteger = buffer.toString().split('').reversed.join();

    return '$symbol$formattedInteger.$decimalPart';
  }

  /// Get currency symbol from code
  static String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return r'$';
      case 'PKR':
        return 'Rs. ';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      case 'AED':
        return 'د.إ ';
      case 'SAR':
        return 'ر.س ';
      default:
        return '$currencyCode ';
    }
  }
}
