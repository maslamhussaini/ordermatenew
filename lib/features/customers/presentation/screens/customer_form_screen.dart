import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/utils/location_helper.dart';
import 'package:ordermate/core/widgets/lookup_field.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/business_partners/presentation/widgets/create_salesman_dialog.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});
  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _matchedAddress;
  bool _isFetchingLocation = false;
  String? _locationError;
  bool _isSubmitting = false;
  final _scrollController = ScrollController();

  int? _selectedBusinessTypeId;
  int? _selectedCityId;
  int? _selectedStateId;
  int? _selectedCountryId;
  String? _selectedChartOfAccountId;
  String? _selectedSalesManId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(businessPartnerProvider.notifier).loadBusinessTypes();
      await ref.read(businessPartnerProvider.notifier).loadCities();
      await ref.read(businessPartnerProvider.notifier).loadStates();
      await ref.read(businessPartnerProvider.notifier).loadCountries();
      await ref.read(businessPartnerProvider.notifier).loadEmployees();
      await ref.read(accountingProvider.notifier).loadAll();

      if (widget.customerId != null) {
        _loadCustomerData();
      } else {
        _setDefaultCityAndCountry();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _zipController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getCityName(int? id) {
    if (id == null) return '';
    final cities = ref.read(businessPartnerProvider).cities;
    final item = cities.firstWhere((e) => e['id'] == id, orElse: () => {});
    return item['city_name'] as String? ?? '';
  }

  String _getStateName(int? id) {
    if (id == null) return '';
    final states = ref.read(businessPartnerProvider).states;
    final item = states.firstWhere((e) => e['id'] == id, orElse: () => {});
    return item['state_name'] as String? ?? '';
  }

  String _getCountryName(int? id) {
    if (id == null) return '';
    final countries = ref.read(businessPartnerProvider).countries;
    final item = countries.firstWhere((e) => e['id'] == id, orElse: () => {});
    return item['country_name'] as String? ?? '';
  }

  void _setDefaultCityAndCountry() {
    // Default: Karachi, Pakistan
    final cities = ref.read(businessPartnerProvider).cities;
    final countries = ref.read(businessPartnerProvider).countries;

    try {
      final khi = cities.firstWhere(
        (c) => (c['city_name'] as String).toLowerCase() == 'karachi',
      );
      _selectedCityId = khi['id'];
    } catch (_) {}

    try {
      final pak = countries.firstWhere(
        (c) => (c['country_name'] as String).toLowerCase() == 'pakistan',
      );
      _selectedCountryId = pak['id'];
    } catch (_) {}

    if (mounted) setState(() {});
  }

  void _loadCustomerData() {
    final customers = ref.read(businessPartnerProvider).customers;
    try {
      final customer = customers.firstWhere((c) => c.id == widget.customerId);
      _nameController.text = customer.name;
      _contactPersonController.text = customer.contactPerson ?? '';
      _phoneController.text = customer.phone;
      _emailController.text = customer.email ?? '';

      _latitude = customer.latitude;
      _longitude = customer.longitude;
      _matchedAddress = 'Saved Location';

      _selectedBusinessTypeId = customer.businessTypeId;
      _selectedCityId = customer.cityId;
      _selectedStateId = customer.stateId;
      _selectedCountryId = customer.countryId;
      _selectedChartOfAccountId = customer.chartOfAccountId;
      _selectedSalesManId = customer.managerId;
      _zipController.text = customer.postalCode ?? '';

      if (customer.cityId != null ||
          customer.countryId != null ||
          customer.stateId != null) {
        _streetController.text = customer.address;
      } else {
        // Fallback for old records or migration
        final parts = customer.address.split(', ');
        if (parts.length >= 4) {
          _streetController.text =
              parts.sublist(0, parts.length - 3).join(', ');
        } else {
          _streetController.text = customer.address;
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading customer data')),
        );
      }
    }
  }

  String get _fullAddress {
    return [
      _streetController.text.trim(),
      _getCityName(_selectedCityId),
      _getStateName(_selectedStateId),
      _zipController.text.trim(),
      _getCountryName(_selectedCountryId),
    ].where((s) => s.isNotEmpty).join(', ');
  }

  Future<void> _setCityByName(String name) async {
    final cities = ref.read(businessPartnerProvider).cities;
    try {
      final existing = cities.firstWhere(
        (e) => (e['city_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCityId = existing['id'];
    } catch (_) {
      await ref.read(businessPartnerProvider.notifier).addCity(name);
      final newCities = ref.read(businessPartnerProvider).cities;
      final newItem = newCities.firstWhere(
        (e) => (e['city_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCityId = newItem['id'];
    }
    if (mounted) setState(() {});
  }

  Future<void> _setStateByName(String name) async {
    final states = ref.read(businessPartnerProvider).states;
    try {
      final existing = states.firstWhere(
        (e) => (e['state_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedStateId = existing['id'];
    } catch (_) {
      await ref.read(businessPartnerProvider.notifier).addState(name);
      final newItems = ref.read(businessPartnerProvider).states;
      final newItem = newItems.firstWhere(
        (e) => (e['state_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedStateId = newItem['id'];
    }
    if (mounted) setState(() {});
  }

  Future<void> _setCountryByName(String name) async {
    final countries = ref.read(businessPartnerProvider).countries;
    try {
      final existing = countries.firstWhere(
        (e) =>
            (e['country_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCountryId = existing['id'];
    } catch (_) {
      await ref.read(businessPartnerProvider.notifier).addCountry(name);
      final newItems = ref.read(businessPartnerProvider).countries;
      final newItem = newItems.firstWhere(
        (e) =>
            (e['country_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCountryId = newItem['id'];
    }
    if (mounted) setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final position = await LocationHelper.getCurrentPosition();
      String? addressText;
      try {
        final placemark = await LocationHelper.getPlacemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        _streetController.text = placemark.street ?? '';
        _zipController.text = placemark.postalCode ?? '';

        if (placemark.locality != null) {
          await _setCityByName(placemark.locality!);
        }
        if (placemark.country != null) {
          await _setCountryByName(placemark.country!);
        }
        if (placemark.administrativeArea != null) {
          await _setStateByName(placemark.administrativeArea!);
        }

        addressText = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.postalCode,
          placemark.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      } catch (_) {
        addressText = 'GPS Coordinates Only';
      }

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _matchedAddress = addressText ?? 'GPS Location';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _updateLocationFromAddress() async {
    final address = _fullAddress;
    if (address.isEmpty) return;

    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        if (mounted) {
          setState(() {
            _latitude = loc.latitude;
            _longitude = loc.longitude;
            _matchedAddress = address;
          });
        }
      } else {
        setState(() => _locationError = 'No location found for this address.');
      }
    } catch (e) {
      setState(() => _locationError = 'Could not find location from address.');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  String _cleanCityName(String rawCity) {
    return rawCity
        .replaceAll(RegExp(r'\s+Division', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+District', caseSensitive: false), '')
        .trim();
  }

  Future<List<Map<String, dynamic>>> _searchAddressWithOSM(String query) async {
    if (query.trim().isEmpty) return [];

    var fullQuery = query;
    final cName = _getCityName(_selectedCityId);
    final cState = _getStateName(_selectedStateId);
    final cCountry = _getCountryName(_selectedCountryId);

    if (cName.isNotEmpty) fullQuery += ', $cName';
    if (cState.isNotEmpty) fullQuery += ', $cState';
    if (cCountry.isNotEmpty) fullQuery += ', $cCountry';

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': fullQuery,
          'format': 'json',
          'addressdetails': 1,
          'limit': 5,
        },
        options: Options(
          headers: {
            'User-Agent': 'OrderMate_FlutterApp/1.0',
            'Accept-Language': 'en',
          },
        ),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      debugPrint('OSM Search Error: $e');
    }
    return [];
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    // Location validation removed to support Offline Mode (Geocoding fails without internet)
    // if (_latitude == null || _longitude == null) { ... }

    setState(() => _isSubmitting = true);

    try {
      final orgState = ref.read(organizationProvider);
      final currentOrgId = orgState.selectedOrganization?.id;
      final currentStoreId = orgState.selectedStore?.id;

      if (currentOrgId == null || currentStoreId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Error: Organization or Store not selected. Please restart the app.')),
          );
        }
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }

      final existing = widget.customerId != null
          ? ref
              .read(businessPartnerProvider)
              .customers
              .cast<BusinessPartner?>()
              .firstWhere((c) => c?.id == widget.customerId, orElse: () => null)
          : null;

      // created_by must be omtbl_users.id (what omtbl_businesspartners
      // .created_by's FK actually targets), never the Supabase Auth UID.
      // Only required when creating a NEW customer -- an update preserves
      // the existing creator via `existing?.createdBy` below and never
      // needs to resolve a fresh identity.
      String? newCreatedBy;
      if (existing == null) {
        final authState = ref.read(authProvider);
        if (!authState.applicationIdentityResolved ||
            authState.userId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Unable to determine the current user. Please sign in again and retry.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isSubmitting = false);
          }
          return;
        }
        newCreatedBy = authState.userId;
      }

      final partner = BusinessPartner(
        id: widget.customerId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _streetController.text
            .trim(), // Save street ONLY to address column, relying on IDs for rest
        latitude: _latitude,
        longitude: _longitude,
        createdBy: existing?.createdBy ?? newCreatedBy,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        businessTypeId: _selectedBusinessTypeId,
        cityId: _selectedCityId,
        stateId: _selectedStateId,
        countryId: _selectedCountryId,
        postalCode: _zipController.text.trim().isEmpty
            ? null
            : _zipController.text.trim(),
        isCustomer: true,
        isActive: true,
        organizationId: existing?.organizationId ?? currentOrgId,
        storeId: existing?.storeId ?? currentStoreId,
        chartOfAccountId: _selectedChartOfAccountId,
        managerId: _selectedSalesManId,
      );

      if (widget.customerId == null) {
        await ref.read(businessPartnerProvider.notifier).addPartner(partner);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer created successfully')));
          context.pop();
        }
      } else {
        final existing = ref
            .read(businessPartnerProvider)
            .customers
            .cast<BusinessPartner?>()
            .firstWhere((c) => c?.id == widget.customerId, orElse: () => null);

        final updatedPartner = partner.copyWith(
          isVendor: existing?.isVendor,
          isEmployee: existing?.isEmployee,
          isSupplier: existing?.isSupplier,
          isCustomer: true,
        );

        await ref
            .read(businessPartnerProvider.notifier)
            .updatePartner(updatedPartner);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer updated successfully')));
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.customerId == null ? 'New Customer' : 'Edit Customer'),
        actions: [
          IconButton(
            onPressed: (_isSubmitting)
                ? null
                : _submitForm, // Allow click to show validation errors even if invalid location, or handle in _submitForm
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
              16, 16, 16, 100), // Added bottom padding
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Basic Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                              labelText: 'Customer Name *',
                              prefixIcon: Icon(Icons.person)),
                          validator: (v) =>
                              v?.isEmpty ?? false ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contactPersonController,
                          decoration: const InputDecoration(
                              labelText: 'Contact Person',
                              prefixIcon: Icon(Icons.badge_outlined)),
                        ),
                        const SizedBox(height: 16),
                        LookupField<Map<String, dynamic>, int>(
                          label: 'Business Type',
                          value: _selectedBusinessTypeId,
                          items:
                              ref.watch(businessPartnerProvider).businessTypes,
                          onChanged: (v) =>
                              setState(() => _selectedBusinessTypeId = v),
                          labelBuilder: (item) =>
                              item['business_type'] as String? ?? 'Unknown',
                          valueBuilder: (item) => item['id'] as int,
                          onAdd: (name) async {
                            await ref
                                .read(businessPartnerProvider.notifier)
                                .addBusinessType(name);
                            // Simple refresh handled by provider updates
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                              labelText: 'Phone *',
                              prefixIcon: Icon(Icons.phone)),
                          validator: (v) =>
                              v?.isEmpty ?? false ? 'Required' : null,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LookupField<BusinessPartner, String>(
                                label: 'SalesMan',
                                value: _selectedSalesManId,
                                items: ref
                                    .watch(businessPartnerProvider)
                                    .employees
                                    .where((e) {
                                  final dept =
                                      e.departmentName?.toLowerCase() ?? '';
                                  final role =
                                      e.roleName?.toLowerCase() ?? '';
                                  return dept == 'sales' && role == 'salesman';
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedSalesManId = v),
                                labelBuilder: (item) => item.name,
                                valueBuilder: (item) => item.id,
                                // Deliberately no `onAdd` here: LookupField's
                                // built-in "+" opens a generic name-only
                                // dialog before calling onAdd, which would
                                // chain a second, redundant dialog on top of
                                // the full Create Salesman dialog below. A
                                // dedicated button opens that dialog directly
                                // instead, matching the requirement that both
                                // entry points use the SAME dialog with no
                                // extra steps.
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: IconButton.filledTonal(
                                onPressed: () async {
                                  final newSalesmanId =
                                      await showCreateSalesmanDialog(context);
                                  if (newSalesmanId != null && mounted) {
                                    setState(() =>
                                        _selectedSalesManId = newSalesmanId);
                                  }
                                },
                                icon: const Icon(Icons.add),
                                tooltip: 'Add new SalesMan',
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LookupField<ChartOfAccount, String>(
                          label: 'Customer GL Account',
                          value: _selectedChartOfAccountId,
                          items:
                              ref.watch(accountingProvider).accounts.where((a) {
                            final categories =
                                ref.read(accountingProvider).categories;
                            final cat = categories.firstWhere(
                                (c) => c.id == a.accountCategoryId,
                                orElse: () => const AccountCategory(
                                    id: 0,
                                    categoryName: '',
                                    accountTypeId: 0,
                                    status: true,
                                    organizationId: 0));
                            return cat.categoryName
                                .toLowerCase()
                                .contains('customer');
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedChartOfAccountId = v),
                          labelBuilder: (item) =>
                              '${item.accountCode} - ${item.accountTitle}',
                          valueBuilder: (item) => item.id,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Address & Location
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Address',
                                style: Theme.of(context).textTheme.titleMedium),
                            TextButton.icon(
                              onPressed: _getCurrentLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Use GPS'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Address Autocomplete
                        Autocomplete<Map<String, dynamic>>(
                          optionsBuilder:
                              (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.length < 3) {
                              return const Iterable<
                                  Map<String, dynamic>>.empty();
                            }
                            return _searchAddressWithOSM(textEditingValue.text);
                          },
                          displayStringForOption: (option) =>
                              option['display_name'] ?? '',
                          fieldViewBuilder: (context, textEditingController,
                              focusNode, onFieldSubmitted) {
                            if (_streetController.text.isNotEmpty &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  _streetController.text;
                            }
                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Street Address *',
                                helperText: 'Type to search location',
                                prefixIcon: Icon(Icons.search),
                              ),
                              validator: (v) =>
                                  v?.isEmpty ?? false ? 'Required' : null,
                              onChanged: (val) => _streetController.text = val,
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxHeight: 300, maxWidth: 350),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);

                                      return ListTile(
                                        leading: const Icon(
                                            Icons.location_on_outlined),
                                        title: Text(
                                            option['display_name'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        subtitle: Text(
                                            'Lat: ${option['lat']}, Lon: ${option['lon']}',
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        onTap: () async {
                                          onSelected(option);

                                          // DEBUG LOGS
                                          // print('--- OSM Address Selection Debug ---');
                                          // print('Raw Option: $option');
                                          final address =
                                              option['address'] ?? {};
                                          // print('Raw Address Map: $address');

                                          final houseNumber =
                                              address['house_number'] ?? '';
                                          final road = address['road'] ??
                                              address['pedestrian'] ??
                                              '';
                                          final suburb = address['suburb'] ??
                                              address['neighbourhood'] ??
                                              address['residential'] ??
                                              '';
                                          final cityDistrict =
                                              address['city_district'] ??
                                                  address['district'] ??
                                                  '';

                                          // Include specific place names if available
                                          final name = address['amenity'] ??
                                              address['shop'] ??
                                              address['building'] ??
                                              address['office'] ??
                                              address['leisure'] ??
                                              address['tourism'] ??
                                              '';

                                          // print('Parsed Parts -> Name: $name, House: $houseNumber, Road: $road, Suburb: $suburb, District: $cityDistrict');

                                          final rawCity = address['city'] ??
                                              address['town'] ??
                                              address['village'] ??
                                              address['county'] ??
                                              '';
                                          final state = address['state'] ??
                                              address['province'] ??
                                              '';
                                          final postcode =
                                              address['postcode'] ?? '';
                                          final country =
                                              address['country'] ?? '';

                                          // print('Parsed Location -> City: $rawCity, State: $state, Postcode: $postcode, Country: $country');

                                          final city = _cleanCityName(
                                              rawCity.toString());
                                          // print('Cleaned City: $city');

                                          // 1. Try to build from granular parts
                                          // We include cityDistrict/district now as user wants e.g. "Nazimabad District"
                                          final streetParts = [
                                            name,
                                            houseNumber,
                                            road,
                                            suburb,
                                            cityDistrict,
                                          ]
                                              .where((s) =>
                                                  s != null &&
                                                  s
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                              .map((s) => s.toString().trim())
                                              .toSet()
                                              .toList();

                                          // print('Initial Street Parts: $streetParts');

                                          // 2. Fallback: Parse display_name if parts are insufficient
                                          String streetText;
                                          // Use fallback if we have very little info

                                          if (streetParts.length < 2) {
                                            // print('Using Fallback (DisplayName parsing)');
                                            final String refined =
                                                option['display_name'] ?? '';
                                            // print('Original DisplayName: $refined');

                                            // Tokens to remove (case insensitive)
                                            final removeTokens = [
                                              city,
                                              state,
                                              country,
                                              postcode,
                                              'Pakistan',
                                              address['county'],
                                            ]
                                                .where((t) =>
                                                    t != null &&
                                                    t.toString().isNotEmpty)
                                                .toList();

                                            // print('Remove Tokens: $removeTokens');

                                            final parts = refined
                                                .split(',')
                                                .map((e) => e.trim())
                                                .toList();
                                            final filteredParts =
                                                parts.where((part) {
                                              for (final t in removeTokens) {
                                                if (part.toLowerCase() ==
                                                    t.toString().toLowerCase()) {
                                                  return false;
                                                }
                                              }
                                              // Specific check for Postal Code (numeric 5 digits)
                                              if (part == postcode.toString()) {
                                                return false;
                                              }

                                              // Check exact matches for city/state/country
                                              if (part.toLowerCase() ==
                                                  city.toLowerCase()) {
                                                return false;
                                              }
                                              if (part.toLowerCase() ==
                                                  state.toLowerCase()) {
                                                return false;
                                              }
                                              if (part.toLowerCase() ==
                                                  'pakistan') {
                                                return false;
                                              }
                                              if (address['county'] != null &&
                                                  part.toLowerCase() ==
                                                      address['county']
                                                          .toString()
                                                          .toLowerCase()) {
                                                return false;
                                              }

                                              return true;
                                            }).toList();

                                            streetText =
                                                filteredParts.join(', ');
                                            // print('Refined (Fallback) Street Text: $streetText');
                                          } else {
                                            streetText = streetParts.join(', ');
                                            // print('Constructed Street Text: $streetText');
                                          }

                                          _streetController.text = streetText;
                                          _zipController.text =
                                              postcode.toString();

                                          if (city.isNotEmpty) {
                                            await _setCityByName(city);
                                          }
                                          if (state.toString().isNotEmpty) {
                                            await _setStateByName(
                                                state.toString());
                                          }
                                          if (country.toString().isNotEmpty) {
                                            await _setCountryByName(country);
                                          }

                                          if (mounted) {
                                            setState(() {
                                              _latitude = double.tryParse(
                                                  option['lat'].toString());
                                              _longitude = double.tryParse(
                                                  option['lon'].toString());
                                              _matchedAddress =
                                                  option['display_name'];
                                              _locationError = null;
                                            });
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // City
                        LookupField<Map<String, dynamic>, int>(
                          label: 'City',
                          value: _selectedCityId,
                          items: ref.watch(businessPartnerProvider).cities,
                          onChanged: (v) => setState(() => _selectedCityId = v),
                          labelBuilder: (item) =>
                              item['city_name'] as String? ?? '',
                          valueBuilder: (item) => item['id'] as int,
                          onAdd: (name) async => _setCityByName(name),
                        ),
                        const SizedBox(height: 16),
                        // Postal Code
                        TextFormField(
                          controller: _zipController,
                          decoration: const InputDecoration(
                            labelText: 'Postal Code',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                          ),
                          onEditingComplete: _updateLocationFromAddress,
                        ),
                        const SizedBox(height: 16),
                        // State/Province
                        LookupField<Map<String, dynamic>, int>(
                          label: 'State/Province',
                          value: _selectedStateId,
                          items: ref.watch(businessPartnerProvider).states,
                          onChanged: (v) =>
                              setState(() => _selectedStateId = v),
                          labelBuilder: (item) =>
                              item['state_name'] as String? ?? '',
                          valueBuilder: (item) => item['id'] as int,
                          onAdd: (name) async => _setStateByName(name),
                        ),
                        const SizedBox(height: 16),
                        // Country
                        LookupField<Map<String, dynamic>, int>(
                          label: 'Country',
                          value: _selectedCountryId,
                          items: ref.watch(businessPartnerProvider).countries,
                          onChanged: (v) =>
                              setState(() => _selectedCountryId = v),
                          labelBuilder: (item) =>
                              item['country_name'] as String? ?? '',
                          valueBuilder: (item) => item['id'] as int,
                          onAdd: (name) async => _setCountryByName(name),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _updateLocationFromAddress,
                          child: const Text('Detect Location from Address'),
                        ),
                        if (_isFetchingLocation)
                          const Padding(
                              padding: EdgeInsets.all(8),
                              child:
                                  Center(child: CircularProgressIndicator())),
                        if (_locationError != null)
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(_locationError!,
                                  style: const TextStyle(color: Colors.red))),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              if (_matchedAddress != null) ...[
                                Text('Location found for: "$_matchedAddress"',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo.shade700),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                const Divider(),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Column(children: [
                                    const Text('LATITUDE',
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12)),
                                    Text(_latitude?.toStringAsFixed(6) ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87))
                                  ]),
                                  Column(children: [
                                    const Text('LONGITUDE',
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12)),
                                    Text(_longitude?.toStringAsFixed(6) ?? '-',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87))
                                  ]),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
