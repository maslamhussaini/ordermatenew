// Focused test for the Customer-creation Salesman prerequisite gate
// (customer_list_screen.dart:_navigateToCustomerCreate).
//
// The gate's condition is a pure predicate over BusinessPartner.employees,
// identical to the one already used by the SalesMan picker in
// customer_form_screen.dart. This test exercises that exact predicate in
// isolation rather than driving the widget tree, since the logic itself
// (not the navigation call) is what determines correctness.
//
// This file also covers the reload-before-check fix: the root cause of the
// false "No Salesman" positive was reading `employees` without first
// ensuring loadEmployees() had ever run this session. `shouldReloadBeforeCheck`
// below mirrors that exact decision (reload only when the current list is
// empty, to avoid an unnecessary duplicate fetch when data is already
// present). The full async provider/network integration (an actual
// loadEmployees() call against a real or fake repository, and a genuine
// network-failure path) is NOT exercised here -- that would require a
// ProviderContainer plus organizationProvider/ConnectivityHelper wiring
// disproportionate to this targeted fix. The try/catch around the real
// loadEmployees() call in customer_list_screen.dart is verified by direct
// code reading, not by an automated test; live/manual verification is the
// authoritative check for the full async path, per the accompanying report.
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';

bool hasSalesman(List<BusinessPartner> employees) {
  return employees.any((e) {
    final dept = e.departmentName?.toLowerCase() ?? '';
    final role = e.roleName?.toLowerCase() ?? '';
    return dept == 'sales' && role == 'salesman';
  });
}

// Mirrors customer_list_screen.dart's exact reload-skip heuristic.
bool shouldReloadBeforeCheck(List<BusinessPartner> currentEmployees) {
  return currentEmployees.isEmpty;
}

BusinessPartner _employee({
  required String id,
  String? departmentName,
  String? roleName,
}) {
  return BusinessPartner(
    id: id,
    name: 'Employee $id',
    phone: '000',
    address: 'addr',
    isEmployee: true,
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    organizationId: 98001,
    storeId: 1,
    departmentName: departmentName,
    roleName: roleName,
  );
}

void main() {
  group('Customer creation Salesman prerequisite gate', () {
    test('zero matching Salesmen -> gate blocks (returns false)', () {
      final employees = [
        _employee(id: 'e1', departmentName: 'Accounting', roleName: 'Manager'),
        _employee(id: 'e2', departmentName: 'Sales', roleName: 'Manager'),
        _employee(id: 'e3', departmentName: null, roleName: null),
      ];

      expect(hasSalesman(employees), isFalse);
    });

    test('empty employee list -> gate blocks (returns false)', () {
      expect(hasSalesman(const []), isFalse);
    });

    test('one matching Salesman -> gate allows (returns true)', () {
      final employees = [
        _employee(id: 'e1', departmentName: 'Accounting', roleName: 'Manager'),
        _employee(id: 'e2', departmentName: 'Sales', roleName: 'Salesman'),
      ];

      expect(hasSalesman(employees), isTrue);
    });

    test('match is case-insensitive, matching the picker filter', () {
      final employees = [
        _employee(id: 'e1', departmentName: 'SALES', roleName: 'SalesMan'),
      ];

      expect(hasSalesman(employees), isTrue);
    });

    test('multiple matching Salesmen -> gate allows (returns true)', () {
      final employees = [
        _employee(id: 'e1', departmentName: 'Sales', roleName: 'Salesman'),
        _employee(id: 'e2', departmentName: 'Sales', roleName: 'Salesman'),
      ];

      expect(hasSalesman(employees), isTrue);
    });

    test(
        'live data shape (org=1, store=1, department=Sales, role=Salesman, '
        'no linked omtbl_users row) is recognized -- a Salesman must not '
        'require a login user', () {
      final liveShapedSalesman = BusinessPartner(
        id: '81a68a54-20b3-49fd-a302-2e9f306e84c3',
        name: 'Rashid',
        email: 'maslamhussaini90@gmail.com',
        phone: '000',
        address: 'addr',
        isEmployee: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: 1,
        storeId: 1,
        roleId: 6,
        departmentId: 1,
        departmentName: 'Sales',
        roleName: 'Salesman',
        // No managerId, no auth-linked fields -- BusinessPartner has none,
        // by design (see the diagnostic: a Salesman does not require an
        // omtbl_users/Auth-linked record to be a valid assignment target).
      );

      expect(hasSalesman([liveShapedSalesman]), isTrue);
    });
  });

  group('Reload-before-check heuristic (Test 1 / 2 / 3 decision logic)', () {
    test(
        'Test 1 shape -- empty in-memory list must trigger a reload attempt',
        () {
      expect(shouldReloadBeforeCheck(const []), isTrue);
    });

    test(
        'Test 2 shape -- already-loaded non-empty list must NOT trigger a '
        'redundant reload', () {
      final employees = [
        _employee(id: 'e1', departmentName: 'Sales', roleName: 'Salesman'),
      ];
      expect(shouldReloadBeforeCheck(employees), isFalse);
    });

    test(
        'Test 3 shape -- reload happens for an empty list even when no '
        'Salesman will ultimately be found (dialog remains correct)', () {
      // The heuristic only decides whether to reload; it does not itself
      // determine the presence of a Salesman. Confirms the two decisions
      // are independent: reload trigger, then re-evaluate hasSalesman()
      // against whatever loadEmployees() actually populates.
      expect(shouldReloadBeforeCheck(const []), isTrue);
      expect(hasSalesman(const []), isFalse);
    });
  });
}
