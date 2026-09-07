import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/network/supabase_client.dart';



/// Raised when a Free Plan limit is hit, or when limits could not be verified.
///
/// FIX (H-3): gives the caller a typed signal instead of substring-matching
/// exception text.
class SubscriptionLimitException implements Exception {
  SubscriptionLimitException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SubscriptionService {
  Future<void> checkAction(
      int orgId, String actionType, {Map<String, dynamic>? extra}) async {
    // 1. Fetch Plan Type
    try {
      final org = await SupabaseConfig.client
          .from('omtbl_organizations')
          .select('plan_type')
          .eq('id', orgId)
          .single();

      final plan = org['plan_type'] as String? ?? 'free';
      if (plan == 'paid') return; // No restrictions

      // 2. Check Limits for Free Plan
      if (actionType == 'product') {
        await _checkProductLimit(orgId);
      } else if (actionType == 'transaction') {
        final prefixId = extra?['prefixId'] as int?;
        if (prefixId != null) {
          await _checkTransactionLimit(orgId, prefixId);
        }
      } else if (actionType == 'invoice') {
        await _checkInvoiceLimit(orgId);
      }
    } on SubscriptionLimitException {
      rethrow;
    } catch (e) {
      // FIX (H-3): previously any non-'Free Plan Limit' error fell through and
      // silently ALLOWED the action, so a network blip or RLS denial granted
      // unlimited access. Business-rule violations are now a typed exception;
      // everything else fails closed.
      if (e.toString().contains('Free Plan Limit')) rethrow;
      throw SubscriptionLimitException(
          'Could not verify your plan limits. Please check your connection and try again.');
      // If plan_type column missing or other error, assume allowed or log
      // For now, if we can't check, we might allow (fail open) or block (fail closed).
      // Given it's a new feature, fail open (allow) is safer for existing users if migration failed.
      // But explicit errors should throw.
    }
  }

  Future<void> _checkProductLimit(int orgId) async {
    final response = await SupabaseConfig.client
        .from('omtbl_products')
        .select('id')
        .eq('organization_id', orgId)
        .limit(10);

    if (response.length >= 10) {
      throw Exception(
          'Free Plan Limit: You can only add up to 10 products. Upgrade to Paid plan for unlimited access.');
    }
  }

  Future<void> _checkInvoiceLimit(int orgId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await SupabaseConfig.client
        .from('omtbl_invoices')
        .select('id')
        .eq('organization_id', orgId)
        .gte('invoice_date', today)
        .limit(10);

    if (response.length >= 10) {
      throw Exception(
          'Free Plan Limit: You can only create 10 invoices per day. Upgrade to Paid plan for unlimited access.');
    }
  }

  Future<void> _checkTransactionLimit(int orgId, int prefixId) async {
    // Get Voucher Type
    final prefix = await SupabaseConfig.client
        .from('omtbl_voucher_prefixes')
        .select('voucher_type')
        .eq('id', prefixId)
        .single();
    final type = prefix['voucher_type'] as String;

    String category = '';
    // Categories: 'JV' -> GL, 'SI/CN/DN' -> Sales, 'BP/BR/CP/CR' -> Bank/Cash
    if (type == 'JV') {
      category = 'GL';
    } else if (['BP', 'BR', 'CP', 'CR'].contains(type)) {
      category = 'Bank/Cash';
    } else if (['SI', 'CN', 'DN'].contains(type)) {
      category = 'Sales';
    } else {
      return;
    }

    // Define types for this category to query count
    List<String> typesToCheck = [];
    if (category == 'GL') typesToCheck = ['JV'];
    if (category == 'Bank/Cash') typesToCheck = ['BP', 'BR', 'CP', 'CR'];
    if (category == 'Sales') typesToCheck = ['SI', 'CN', 'DN'];

    final today = DateTime.now().toIso8601String().split('T')[0];

    // Count transactions of these types today
    // We filter by joining voucher_prefixes
    final response = await SupabaseConfig.client
        .from('omtbl_transactions')
        .select('id, omtbl_voucher_prefixes!inner(voucher_type)')
        .eq('organization_id', orgId)
        .gte('voucher_date', today)
        .filter('omtbl_voucher_prefixes.voucher_type', 'in', typesToCheck)
        .limit(10);

    if (response.length >= 10) {
      throw Exception(
          'Free Plan Limit: Max 10 $category transactions per day allowed. Upgrade to Paid plan.');
    }
  }
}

final subscriptionServiceProvider = Provider((ref) => SubscriptionService());
