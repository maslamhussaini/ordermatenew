// ignore_for_file: avoid_print
//
// CONTROLLED VERIFICATION TEST -- accounting session lifecycle, LOCAL layer.
//
// Drives ONLY real LocalAccountingRepository methods against the real
// DatabaseHelper.instance singleton (sqflite_common_ffi). No production
// file is modified by this test; it only reads/writes rows for the
// dedicated org id range 95001 / 95002.
//
// Debit/credit convention used here is the one the app itself uses in
// ReportRepositoryImpl.getLedgerData (report_repository_impl.dart:80-84):
//   account_id        => DEBIT side
//   offset_account_id => CREDIT side
//   amount            => the single amount for both legs

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/accounting/data/models/accounting_models.dart';
import 'package:ordermate/features/accounting/data/models/opening_balance_model.dart';
import 'package:ordermate/features/accounting/data/repositories/local_accounting_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int orgA = 95001;
const int orgB = 95002;
const int syearA = 2025; // "FY 2025-26"
const int syearB = 2026; // "FY 2026-27"

// ---- Org A controlled figures -------------------------------------------
const double saleAmt = 100000.0;
const double cogsAmt = 60000.0;
const double othIncAmt = 5000.0;
const double othExpAmt = 2000.0;
const double capitalAmt = 50000.0;

// ---- Org B controlled figures (deliberately different) -------------------
const double saleAmtB = 7000.0;

// Account type ids (global table, no org scoping in getAccountTypes)
const int tAsset = 950001;
const int tLiability = 950002;
const int tEquity = 950003;
const int tRevenue = 950004;
const int tExpense = 950005;

late LocalAccountingRepository repo;

String _acc(String code) => 'coa_$code';

ChartOfAccountModel _coa(
    String code, String title, int typeId, int catId, int org) {
  final now = DateTime.now();
  return ChartOfAccountModel(
    id: _acc(code),
    accountCode: code,
    accountTitle: title,
    level: 1,
    accountTypeId: typeId,
    accountCategoryId: catId,
    organizationId: org,
    isActive: true,
    isSystem: false,
    createdAt: now,
    updatedAt: now,
  );
}

TransactionModel _txn({
  required String id,
  required String debit,
  required String credit,
  required double amount,
  required String desc,
  required int org,
  required int sYear,
}) {
  return TransactionModel(
    id: id,
    voucherPrefixId: 1,
    voucherNumber: id,
    voucherDate: DateTime(sYear, 7, 1),
    accountId: _acc(debit),
    offsetAccountId: _acc(credit),
    amount: amount,
    description: desc,
    status: 'posted',
    organizationId: org,
    storeId: 1,
    sYear: sYear,
  );
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    repo = LocalAccountingRepository();

    // Purge any leftovers from a previous run of THIS test only.
    final db = await DatabaseHelper.instance.database;
    for (final t in [
      'local_transactions',
      'local_chart_of_accounts',
      'local_financial_sessions',
      'local_opening_balances',
    ]) {
      await db.delete(t,
          where: 'organization_id IN (?, ?)', whereArgs: [orgA, orgB]);
    }
    await db.delete('local_account_types',
        where: 'id BETWEEN ? AND ?', whereArgs: [950001, 950099]);
    await db.delete('local_account_categories',
        where: 'id BETWEEN ? AND ?', whereArgs: [950001, 950099]);
  });

  test('FULL LIFECYCLE: Session A -> close -> Session B', () async {
    // ================= 1. SESSION A SETUP =================
    print('\n========== STEP 1: SESSION A SETUP (org $orgA) ==========');

    for (final t in [
      AccountTypeModel(
          id: tAsset, typeName: 'Asset', organizationId: orgA, status: true),
      AccountTypeModel(
          id: tLiability,
          typeName: 'Liability',
          organizationId: orgA,
          status: true),
      AccountTypeModel(
          id: tEquity, typeName: 'Equity', organizationId: orgA, status: true),
      AccountTypeModel(
          id: tRevenue, typeName: 'Revenue', organizationId: orgA, status: true),
      AccountTypeModel(
          id: tExpense, typeName: 'Expense', organizationId: orgA, status: true),
    ]) {
      await repo.saveAccountType(t);
    }

    final cats = <int, List<dynamic>>{
      950011: ['Current Assets', tAsset],
      950012: ['Current Liabilities', tLiability],
      950013: ['Capital', tEquity],
      950014: ['Operating Revenue', tRevenue],
      950015: ['Cost of Sales', tExpense],
      950016: ['Other Income', tRevenue],
      950017: ['Other Expense', tExpense],
    };
    for (final e in cats.entries) {
      await repo.saveAccountCategory(AccountCategoryModel(
        id: e.key,
        categoryName: e.value[0] as String,
        accountTypeId: e.value[1] as int,
        organizationId: orgA,
      ));
    }
    print('AccountTypes saved: ${(await repo.getAccountTypes()).where((t) => t.id >= 950001 && t.id <= 950099).length}');
    print('AccountCategories saved: ${(await repo.getAccountCategories()).where((c) => c.id >= 950001 && c.id <= 950099).length}');

    // Chart of accounts for Org A. account_code is globally UNIQUE in
    // local_chart_of_accounts, hence the A-/B- prefixes.
    final coaA = <ChartOfAccountModel>[
      _coa('A-1000', 'Cash & Bank', tAsset, 950011, orgA),
      _coa('A-1100', 'Accounts Receivable', tAsset, 950011, orgA),
      _coa('A-2000', 'Accounts Payable', tLiability, 950012, orgA),
      _coa('A-3000', 'Owner Capital', tEquity, 950013, orgA),
      _coa('A-4000', 'Sales Revenue', tRevenue, 950014, orgA),
      _coa('A-4900', 'Other Income', tRevenue, 950016, orgA),
      _coa('A-5000', 'Cost of Sales', tExpense, 950015, orgA),
      _coa('A-5900', 'Other Expense', tExpense, 950017, orgA),
    ];
    for (final a in coaA) {
      await repo.saveChartOfAccount(a);
    }

    final readCoaA = await repo.getChartOfAccounts(organizationId: orgA);
    print('getChartOfAccounts(org $orgA) -> ${readCoaA.length} rows:');
    for (final a in readCoaA) {
      print('   ${a.accountCode.padRight(8)} ${a.accountTitle.padRight(22)} '
          'type=${a.accountTypeId} cat=${a.accountCategoryId} org=${a.organizationId}');
    }
    expect(readCoaA.length, 8);

    await repo.saveFinancialSession(FinancialSessionModel(
      sYear: syearA,
      startDate: DateTime(2025, 7, 1),
      endDate: DateTime(2026, 6, 30),
      narration: 'FY 2025-26',
      inUse: true,
      isActive: true,
      isClosed: false,
      organizationId: orgA,
    ));
    final sessA = await repo.getFinancialSessions(organizationId: orgA);
    print('getFinancialSessions(org $orgA) -> ${sessA.length} row(s):');
    for (final s in sessA) {
      print('   syear=${s.sYear} inUse=${s.inUse} isClosed=${s.isClosed} '
          'narration=${s.narration} org=${s.organizationId}');
    }
    expect(sessA.length, 1);
    expect(sessA.first.isClosed, false);

    // ================= 2. SESSION A TRANSACTIONS =================
    print('\n========== STEP 2: SESSION A TRANSACTIONS ==========');
    final txns = <TransactionModel>[
      _txn(
          id: 'A-TX-01',
          debit: 'A-1100',
          credit: 'A-4000',
          amount: saleAmt,
          desc: 'Credit sale',
          org: orgA,
          sYear: syearA),
      _txn(
          id: 'A-TX-02',
          debit: 'A-5000',
          credit: 'A-2000',
          amount: cogsAmt,
          desc: 'Cost of sales',
          org: orgA,
          sYear: syearA),
      _txn(
          id: 'A-TX-03',
          debit: 'A-1000',
          credit: 'A-4900',
          amount: othIncAmt,
          desc: 'Other income',
          org: orgA,
          sYear: syearA),
      _txn(
          id: 'A-TX-04',
          debit: 'A-5900',
          credit: 'A-1000',
          amount: othExpAmt,
          desc: 'Other expense',
          org: orgA,
          sYear: syearA),
      _txn(
          id: 'A-TX-05',
          debit: 'A-1000',
          credit: 'A-3000',
          amount: capitalAmt,
          desc: 'Capital injection',
          org: orgA,
          sYear: syearA),
    ];
    for (final t in txns) {
      await repo.saveTransaction(t);
      print('POSTED ${t.id}: Dr ${t.accountId} / Cr ${t.offsetAccountId} '
          '= ${t.amount}  (${t.description})');
    }

    // ================= 3. READ BACK VIA APP METHODS =================
    print('\n========== STEP 3: READ BACK (repo.getTransactions) ==========');
    final readTx =
        await repo.getTransactions(organizationId: orgA, sYear: syearA);
    print('getTransactions(org $orgA, sYear $syearA) -> ${readTx.length} rows');
    expect(readTx.length, 5);

    // NOTE (manually derived): no Trial Balance / P&L / Balance Sheet
    // calculation method exists anywhere in lib/. Balances below are summed
    // from the raw rows getTransactions() returns.
    final debitByAcc = <String, double>{};
    final creditByAcc = <String, double>{};
    for (final t in readTx) {
      debitByAcc[t.accountId] = (debitByAcc[t.accountId] ?? 0) + t.amount;
      if (t.offsetAccountId != null) {
        creditByAcc[t.offsetAccountId!] =
            (creditByAcc[t.offsetAccountId!] ?? 0) + t.amount;
      }
    }

    final titles = {for (final a in readCoaA) a.id: a.accountTitle};
    final allAccs = {...debitByAcc.keys, ...creditByAcc.keys}.toList()..sort();

    print('\n--- TRIAL BALANCE (manually derived from getTransactions) ---');
    print('${'Account'.padRight(34)}${'Debit'.padLeft(14)}${'Credit'.padLeft(14)}');
    double totalDr = 0, totalCr = 0;
    for (final id in allAccs) {
      final d = debitByAcc[id] ?? 0;
      final c = creditByAcc[id] ?? 0;
      totalDr += d;
      totalCr += c;
      print('${(titles[id] ?? id).padRight(34)}'
          '${d.toStringAsFixed(2).padLeft(14)}'
          '${c.toStringAsFixed(2).padLeft(14)}');
    }
    print('${'TOTAL'.padRight(34)}'
        '${totalDr.toStringAsFixed(2).padLeft(14)}'
        '${totalCr.toStringAsFixed(2).padLeft(14)}');

    // ================= 4. COMPUTE & REPORT =================
    print('\n========== STEP 4: P&L ==========');
    double bal(String code) =>
        (debitByAcc[_acc(code)] ?? 0) - (creditByAcc[_acc(code)] ?? 0);

    final sales = -bal('A-4000');
    final cogs = bal('A-5000');
    final otherIncome = -bal('A-4900');
    final otherExpense = bal('A-5900');
    final grossProfit = sales - cogs;
    final netProfit = grossProfit + otherIncome - otherExpense;

    print('Sales           : ${sales.toStringAsFixed(2)}');
    print('Cost of Sales   : ${cogs.toStringAsFixed(2)}');
    print('GROSS PROFIT    : ${grossProfit.toStringAsFixed(2)}');
    print('Other Income    : ${otherIncome.toStringAsFixed(2)}');
    print('Other Expense   : ${otherExpense.toStringAsFixed(2)}');
    print('NET PROFIT      : ${netProfit.toStringAsFixed(2)}');

    expect(totalDr, totalCr);
    expect(totalDr, saleAmt + cogsAmt + othIncAmt + othExpAmt + capitalAmt);
    expect(grossProfit, saleAmt - cogsAmt);
    expect(netProfit, (saleAmt - cogsAmt) + othIncAmt - othExpAmt);

    // Balance-sheet closing figures (what SHOULD carry into Session B)
    final bsClosing = <String, double>{
      'A-1000 Cash & Bank': bal('A-1000'),
      'A-1100 Accounts Receivable': bal('A-1100'),
      'A-2000 Accounts Payable': bal('A-2000'),
      'A-3000 Owner Capital': bal('A-3000'),
    };
    print('\n--- SESSION A CLOSING BALANCE-SHEET BALANCES (Dr +ve / Cr -ve) ---');
    bsClosing.forEach((k, v) => print('   ${k.padRight(30)} ${v.toStringAsFixed(2)}'));
    print('   ${'RETAINED EARNINGS (net profit)'.padRight(30)} ${netProfit.toStringAsFixed(2)}');

    // ================= 5. SESSION CLOSE =================
    print('\n========== STEP 5: FINANCIAL SESSION CLOSE ==========');
    print('Searched lib/ for closeSession / close_session / closeFinancial* /');
    print('yearEnd / carryForward / rollover  -> NO MATCHES.');
    print('LocalAccountingRepository exposes NO close method. The only local');
    print('write path that can flip is_closed is saveFinancialSession() with a');
    print('hand-built model. Exercising that now:');

    await repo.saveFinancialSession(FinancialSessionModel(
      sYear: syearA,
      startDate: DateTime(2025, 7, 1),
      endDate: DateTime(2026, 6, 30),
      narration: 'FY 2025-26',
      inUse: false,
      isActive: true,
      isClosed: true, // <-- manual flag flip, NOT an app close routine
      organizationId: orgA,
    ));

    final sessAfter = await repo.getFinancialSessions(organizationId: orgA);
    print('getFinancialSessions(org $orgA) after "close" -> ${sessAfter.length} row(s):');
    for (final s in sessAfter) {
      print('   syear=${s.sYear} inUse=${s.inUse} isClosed=${s.isClosed}');
    }
    print('=> is_closed flipped to true, and NO duplicate row was created:');
    print('   UNIQUE INDEX idx_fin_session_org_year(organization_id, syear)');
    print('   (database_helper.dart:2272) makes ConflictAlgorithm.replace upsert');
    print('   correctly even though toLocalMap() omits `id`.');
    print('=> BUT: flipping the flag is ALL that happens. No closing entries are');
    print('   posted, no retained-earnings transfer, no opening balances written.');
    expect(sessAfter.length, 1);
    expect(sessAfter.first.isClosed, true);

    // ================= 6. SESSION B + OPENING BALANCES =================
    print('\n========== STEP 6: SESSION B (FY 2026-27) + OPENING BALANCES ==========');
    await repo.saveFinancialSession(FinancialSessionModel(
      sYear: syearB,
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2027, 6, 30),
      narration: 'FY 2026-27',
      inUse: true,
      isActive: true,
      isClosed: false,
      organizationId: orgA,
    ));

    final obAuto =
        await repo.getOpeningBalances(organizationId: orgA, sYear: syearB);
    print('getOpeningBalances(org $orgA, sYear $syearB) immediately after');
    print('creating Session B -> ${obAuto.length} rows.');
    print('=> NO automatic carry-forward of Session A closing balances.');
    expect(obAuto.length, 0);

    print('\nDemonstrating that saveOpeningBalance() DOES work when the caller');
    print('supplies the figures itself (i.e. the storage exists, the automation');
    print('does not):');
    var i = 0;
    for (final e in bsClosing.entries) {
      final code = e.key.split(' ').first;
      await repo.saveOpeningBalance(OpeningBalanceModel(
        id: 'OB-A-${syearB}-${++i}',
        sYear: syearB,
        amount: e.value,
        entityId: _acc(code),
        entityType: 'chart_of_account',
        organizationId: orgA,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    final obManual =
        await repo.getOpeningBalances(organizationId: orgA, sYear: syearB);
    print('getOpeningBalances(org $orgA, sYear $syearB) after manual writes '
        '-> ${obManual.length} rows:');
    for (final b in obManual) {
      print('   ${b.entityId.padRight(14)} ${b.amount.toStringAsFixed(2).padLeft(12)} '
          'type=${b.entityType} syear=${b.sYear}');
    }
    expect(obManual.length, 4);
    for (final b in obManual) {
      final expected = bsClosing.entries
          .firstWhere((e) => _acc(e.key.split(' ').first) == b.entityId)
          .value;
      expect(b.amount, expected);
    }
    print('Manual opening balances match Session A closing figures exactly.');
    print('But nothing in the app produced them -- the test did.');

    // ================= 7. ORG ISOLATION CONTROL =================
    print('\n========== STEP 7: ORG ISOLATION (org $orgB) ==========');
    final coaB = <ChartOfAccountModel>[
      _coa('B-1000', 'B Cash', tAsset, 950011, orgB),
      _coa('B-4000', 'B Sales', tRevenue, 950014, orgB),
    ];
    for (final a in coaB) {
      await repo.saveChartOfAccount(a);
    }
    await repo.saveFinancialSession(FinancialSessionModel(
      sYear: syearA,
      startDate: DateTime(2025, 7, 1),
      endDate: DateTime(2026, 6, 30),
      narration: 'Org B FY 2025-26',
      inUse: true,
      isActive: true,
      isClosed: false,
      organizationId: orgB,
    ));
    await repo.saveTransaction(_txn(
        id: 'B-TX-01',
        debit: 'B-1000',
        credit: 'B-4000',
        amount: saleAmtB,
        desc: 'Org B cash sale',
        org: orgB,
        sYear: syearA));

    final aCoa = await repo.getChartOfAccounts(organizationId: orgA);
    final bCoa = await repo.getChartOfAccounts(organizationId: orgB);
    final aTx = await repo.getTransactions(organizationId: orgA);
    final bTx = await repo.getTransactions(organizationId: orgB);
    final aSess = await repo.getFinancialSessions(organizationId: orgA);
    final bSess = await repo.getFinancialSessions(organizationId: orgB);

    final leaks = <String>[];
    for (final a in aCoa) {
      if (a.accountCode.startsWith('B-')) leaks.add('COA org A leaked ${a.accountCode}');
    }
    for (final a in bCoa) {
      if (a.accountCode.startsWith('A-')) leaks.add('COA org B leaked ${a.accountCode}');
    }
    for (final t in aTx) {
      if (t.id.startsWith('B-')) leaks.add('TX org A leaked ${t.id}');
    }
    for (final t in bTx) {
      if (t.id.startsWith('A-')) leaks.add('TX org B leaked ${t.id}');
    }
    for (final s in aSess) {
      if (s.organizationId != orgA) leaks.add('SESSION org A leaked org ${s.organizationId}');
    }
    for (final s in bSess) {
      if (s.organizationId != orgB) leaks.add('SESSION org B leaked org ${s.organizationId}');
    }

    print('getChartOfAccounts(orgA)=${aCoa.length}  (orgB)=${bCoa.length}');
    print('getTransactions(orgA)=${aTx.length}   (orgB)=${bTx.length}');
    print('getFinancialSessions(orgA)=${aSess.length}  (orgB)=${bSess.length}');
    print('CROSS-ORG LEAKED ROWS: ${leaks.isEmpty ? "0 cross-org rows found" : leaks}');
    expect(leaks, isEmpty);

    final bTotal = bTx.fold<double>(0, (p, t) => p + t.amount);
    print('Org B transaction total = ${bTotal.toStringAsFixed(2)} '
        '(expected ${saleAmtB.toStringAsFixed(2)})');
    expect(bTotal, saleAmtB);

    print('\n========== DONE ==========');
  });
}
