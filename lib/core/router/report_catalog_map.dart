import 'package:ordermate/core/router/route_names.dart';

/// Resolves the live `omtbl_app_forms.id` for the three parameterized report
/// routes (ledger/:type, sales/:groupBy, returns/:groupBy) that fan out to
/// multiple catalog rows depending on a runtime path parameter and therefore
/// cannot carry a single static `AppRoute.formId` (see the doc comment on
/// `AppRoute.formId`).
///
/// IDs below were live-verified against `omtbl_app_forms` in the Phase 3B
/// audit session (2026-09-03) -- never invented. Returns null for any
/// routeName/param combination this map doesn't recognize, in which case the
/// caller (app_router.dart) treats the route as non-catalog (existing
/// role-only behavior, unchanged).
int? resolveParameterizedReportFormId(
    String? routeName, Map<String, String> pathParameters) {
  switch (routeName) {
    case RouteNames.ledgerReport:
      switch (pathParameters['type']) {
        case 'customer':
          return 9; // RPT_LEDGER_CUSTOMER
        case 'vendor':
          return 10; // RPT_LEDGER_VENDOR
        case 'bank':
          return 11; // RPT_LEDGER_BANK
        case 'cash':
          return 12; // RPT_LEDGER_CASH
        case 'gl':
          return 13; // RPT_LEDGER_GL
      }
      return null;

    case RouteNames.salesReport:
      switch (pathParameters['groupBy']) {
        case 'product':
          return 14; // RPT_SALES_PRODUCT
        case 'customer':
          return 15; // RPT_SALES_CUSTOMER
      }
      return null;

    case RouteNames.returnsReport:
      switch (pathParameters['groupBy']) {
        case 'product':
          return 16; // RPT_RETURNS_PRODUCT
        case 'customer':
          return 17; // RPT_RETURNS_CUSTOMER
      }
      return null;

    case RouteNames.customerWiseSales:
      return 21; // RPT_CUSTOMER_WISE_SALES
    case RouteNames.itemWiseSales:
      return 22; // RPT_ITEM_WISE_SALES
    case RouteNames.grossSales:
      return 23; // RPT_GROSS_SALES
    case RouteNames.netSales:
      return 24; // RPT_NET_SALES
    case RouteNames.salesInvoiceItemWise:
      return 25; // RPT_SALES_INVOICE_ITEM_WISE
    case RouteNames.salesInvoiceCustomerWise:
      return 26; // RPT_SALES_INVOICE_CUSTOMER_WISE
    case RouteNames.salesReturnItemWise:
      return 27; // RPT_SALES_RETURN_ITEM_WISE
    case RouteNames.salesReturnCustomerWise:
      return 28; // RPT_SALES_RETURN_CUSTOMER_WISE
    case RouteNames.monthWiseSales:
      return 29; // RPT_MONTH_WISE_SALES
    case RouteNames.receivableReport:
      return 30; // RPT_RECEIVABLE
    case RouteNames.customerBalance:
      return 31; // RPT_CUSTOMER_BALANCE
    case RouteNames.productList:
      return 32; // RPT_PRODUCT_LIST
    case RouteNames.categoryWise:
      return 33; // RPT_CATEGORY_WISE
    case RouteNames.brandWise:
      return 34; // RPT_BRAND_WISE
    case RouteNames.typeWise:
      return 35; // RPT_TYPE_WISE
    case RouteNames.supplierWise:
      return 36; // RPT_SUPPLIER_WISE
    case RouteNames.orderListReport:
      return 37; // RPT_ORDER_LIST
  }
  return null;
}
