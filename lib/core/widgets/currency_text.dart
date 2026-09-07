// lib/core/widgets/currency_text.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/providers/store_provider.dart';
import 'package:ordermate/core/utils/currency_utils.dart';

/// A widget that displays an amount with the current store's currency
class CurrencyText extends ConsumerWidget {
  const CurrencyText(
    this.amount, {
    this.style,
    this.useSymbol = true,
    super.key,
  });

  final double amount;
  final TextStyle? style;
  final bool useSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyCode = ref.watch(currentCurrencyProvider);
    final formatted = useSymbol
        ? CurrencyUtils.formatWithSymbol(amount, currencyCode)
        : CurrencyUtils.formatCurrency(amount, currencyCode);

    return Text(formatted, style: style);
  }
}
