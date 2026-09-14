import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/utils/iterable_extensions.dart';
import 'package:ordermate/core/widgets/lookup_field.dart';

import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/products/presentation/providers/recipe_provider.dart';
import 'package:ordermate/features/vendors/domain/entities/vendor.dart';
import 'package:ordermate/features/vendors/presentation/providers/vendor_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController(text: '0.0');
  final _priceController = TextEditingController(text: '0.0');
  final _limitPriceController = TextEditingController(text: '0.0');
  final _stockQtyController = TextEditingController(text: '0.0');
  final _baseQuantityController = TextEditingController(text: '1.0');
  final _defaultDiscountController = TextEditingController(text: '0.0');
  final _discountLimitController = TextEditingController(text: '0.0');

  // Selected Values
  int? _selectedTypeId;
  int? _selectedCategoryId;
  int? _selectedBrandId;
  int? _selectedUomId;
  String? _uomSymbol;
  String? _selectedBusinessPartnerId;

  // GL Accounts
  String? _selectedInventoryGlId;
  String? _selectedCogsGlId;
  String? _selectedRevenueGlId;
  String? _selectedSalesDiscountGlId;

  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  double _afterDiscountPrice = 0.0;

  // Recipe state
  final List<ProductRecipe> _ingredients = [];
  bool _isRecipe = false;
  double _recipeCost = 0.0;
  bool _isRecipeLoading = false;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_calculateAfterDiscount);
    _discountLimitController.addListener(_calculateAfterDiscount);
    _limitPriceController.addListener(_calculateAfterDiscount);
    Future.microtask(_loadInitialData);
  }

  void _calculateAfterDiscount() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final discLimit = double.tryParse(_discountLimitController.text) ?? 0.0;

    setState(() {
      _afterDiscountPrice = price * (1 - (discLimit / 100));
    });
  }

  bool _isRecipeProductType() {
    if (_selectedTypeId == null) return false;
    final productType = ref.read(inventoryProvider).productTypes.firstWhereOrNull(
        (t) => t.id == _selectedTypeId);
    return productType?.name.toLowerCase() == 'recipe';
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(ProductRecipe(
        id: '',
        productId: widget.productId ?? '',
        componentProductId: '',
        quantity: 0.0,
        uomId: 0,
        wastagePercent: 0.0,
        organizationId: ref.read(organizationProvider).selectedOrganizationId ?? 0,
      ));
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  Future<void> _loadRecipe(String productId) async {
    if (!_isRecipeProductType()) {
      setState(() {
        _ingredients.clear();
        _recipeCost = 0.0;
      });
      return;
    }

    setState(() => _isRecipeLoading = true);
    try {
      await ref.read(recipeProvider.notifier).loadRecipes(productId);
      setState(() {
        _ingredients.clear();
        _ingredients.addAll(ref.read(recipeProvider).recipes);
      });

      final cost = await ref.read(recipeProvider.notifier).calculateRecipeCost(productId);
      setState(() {
        _recipeCost = cost;
      });
    } catch (e) {
      debugPrint('ProductForm: Error loading recipe: $e');
    } finally {
      if (mounted) setState(() => _isRecipeLoading = false);
    }
  }

  Future<void> _saveRecipe(String productId) async {
    if (!_isRecipeProductType()) return;

    try {
      await ref.read(recipeProvider.notifier).saveRecipe(productId, _ingredients);
    } catch (e) {
      debugPrint('ProductForm: Error saving recipe: $e');
      rethrow;
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      debugPrint('ProductForm: Loading initial data for Org $orgId...');

      await Future.wait([
        ref
            .read(inventoryProvider.notifier)
            .loadAll()
            .timeout(const Duration(seconds: 15))
            .catchError((e) {
          debugPrint('ProductForm: Inventory load error: $e');
          return;
        }),
        ref
            .read(vendorProvider.notifier)
            .loadVendors()
            .timeout(const Duration(seconds: 15))
            .catchError((e) {
          debugPrint('ProductForm: Vendors load error: $e');
          return;
        }),
        ref
            .read(vendorProvider.notifier)
            .loadSuppliers()
            .timeout(const Duration(seconds: 15))
            .catchError((e) {
          debugPrint('ProductForm: Suppliers load error: $e');
          return;
        }),
        ref
            .read(accountingProvider.notifier)
            .loadAll(organizationId: orgId)
            .timeout(const Duration(seconds: 20))
            .catchError((e) {
          debugPrint('ProductForm: Accounting load error: $e');
          return;
        }),
      ]);

      if (!mounted) return;

      final accState = ref.read(accountingProvider);
      debugPrint(
          'ProductForm: Data Load Complete. Accounts: ${accState.accounts.length}');

      if (accState.accounts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Warning: No Accounting Data loaded. Check internet or permissions.'),
            backgroundColor: Colors.orange,
          ));
        }
      }

      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra.containsKey('vendorId')) {
        final vId = extra['vendorId'] as String;
        final vState = ref.read(vendorProvider);
        final vendor = [...vState.vendors, ...vState.suppliers]
            .cast<Vendor?>()
            .firstWhere((v) => v?.id == vId, orElse: () => null);

        if (vendor != null) {
          _selectedBusinessPartnerId = vId;
          try {
            final matchingBrand = ref.read(inventoryProvider).brands.firstWhere(
                  (b) => b.name.toLowerCase() == vendor.name.toLowerCase(),
                );
            _selectedBrandId = matchingBrand.id;
          } catch (_) {}
        }
      }

      if (widget.productId != null) {
        final products = ref.read(productProvider).products;
        if (products.isEmpty) {
          await ref.read(productProvider.notifier).loadProducts();
        }

        final product =
            ref.read(productProvider).products.cast<Product>().firstWhere(
                  (p) => p.id == widget.productId,
                  orElse: () => throw Exception('Product not found'),
                );

        _nameController.text = product.name;
        _skuController.text = product.sku;
        _descriptionController.text = product.description ?? '';
        _costController.text = product.cost.toString();
        _priceController.text = product.rate.toString();
        _limitPriceController.text = product.limitPrice.toString();
        _stockQtyController.text = product.stockQty.toString();
        _baseQuantityController.text = product.baseQuantity.toString();
        _selectedUomId = product.uomId;
        _uomSymbol = product.uomSymbol;
        _selectedInventoryGlId = product.inventoryGlId;
        _selectedCogsGlId = product.cogsGlId;
        _selectedRevenueGlId = product.revenueGlId;
        _selectedSalesDiscountGlId = product.salesDiscountGlId;
        _defaultDiscountController.text =
            product.defaultDiscountPercent.toString();
        _discountLimitController.text =
            product.defaultDiscountPercentLimit.toString();

        final invState = ref.read(inventoryProvider);
        final vendorState = ref.read(vendorProvider);

        if (invState.productTypes.any((t) => t.id == product.productTypeId)) {
          _selectedTypeId = product.productTypeId;
        }
        if (invState.categories.any((c) => c.id == product.categoryId)) {
          _selectedCategoryId = product.categoryId;
        }
        if (invState.brands.any((b) => b.id == product.brandId)) {
          _selectedBrandId = product.brandId;
        }
        if ([...vendorState.vendors, ...vendorState.suppliers]
            .any((v) => v.id == product.businessPartnerId)) {
          _selectedBusinessPartnerId = product.businessPartnerId;
        }

        _selectedSalesDiscountGlId ??=
            ref.read(accountingProvider).glSetup?.salesDiscountAccountId;

        final selectedType = ref.read(inventoryProvider).productTypes
            .firstWhereOrNull((t) => t.id == product.productTypeId);
        _isRecipe = selectedType?.name.toLowerCase() == 'recipe';

        if (_isRecipe) {
          await _loadRecipe(widget.productId!);
        }
      } else {
        final setup = ref.read(accountingProvider).glSetup;
        if (setup != null) {
          _selectedInventoryGlId = setup.inventoryAccountId;
          _selectedCogsGlId = setup.cogsAccountId;
          _selectedRevenueGlId = setup.salesAccountId;
          _selectedSalesDiscountGlId = setup.salesDiscountAccountId;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_calculateAfterDiscount);
    _discountLimitController.removeListener(_calculateAfterDiscount);
    _limitPriceController.removeListener(_calculateAfterDiscount);
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _limitPriceController.dispose();
    _stockQtyController.dispose();
    _baseQuantityController.dispose();
    _defaultDiscountController.dispose();
    _discountLimitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ChartOfAccount> _getFilteredAccounts(
      String categoryKeyword, AccountingState accState) {
    final allAccounts = accState.accounts;
    final categories = accState.categories;

    final strictMatches = allAccounts.where((account) {
      if (account.accountCategoryId == null) return false;
      final cat = categories.firstWhere(
          (c) => c.id == account.accountCategoryId,
          orElse: () => const AccountCategory(
              id: 0,
              categoryName: '',
              accountTypeId: 0,
              organizationId: 0,
              status: false));
      if (!cat.categoryName
          .toLowerCase()
          .contains(categoryKeyword.toLowerCase())) {
        return false;
      }
      if (account.level != 3 && account.level != 4) return false;
      return true;
    }).toList();

    if (strictMatches.isNotEmpty) {
      return strictMatches
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    }

    final relaxedMatches = allAccounts.where((account) {
      final cat = categories.firstWhere(
          (c) => c.id == account.accountCategoryId,
          orElse: () => const AccountCategory(
              id: 0,
              categoryName: '',
              accountTypeId: 0,
              organizationId: 0,
              status: false));
      final matchesCategory = cat.categoryName
          .toLowerCase()
          .contains(categoryKeyword.toLowerCase());
      final matchesTitle = account.accountTitle
          .toLowerCase()
          .contains(categoryKeyword.toLowerCase());
      return matchesCategory || matchesTitle;
    }).toList();

    if (relaxedMatches.isNotEmpty) {
      return relaxedMatches
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    }

    return allAccounts.toList()
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final orgState = ref.read(organizationProvider);
      final product = Product(
        id: widget.productId ?? '',
        name: _nameController.text.trim(),
        sku: _skuController.text.trim(),
        description: _descriptionController.text.trim(),
        rate: double.tryParse(_priceController.text) ?? 0.0,
        cost: double.tryParse(_costController.text) ?? 0.0,
        limitPrice: double.tryParse(_limitPriceController.text) ?? 0.0,
        stockQty: double.tryParse(_stockQtyController.text) ?? 0.0,
        inventoryGlId: _selectedInventoryGlId,
        cogsGlId: _selectedCogsGlId,
        revenueGlId: _selectedRevenueGlId,
        businessPartnerId: (_selectedBusinessPartnerId?.isEmpty ?? true)
            ? null
            : _selectedBusinessPartnerId,
        productTypeId: _selectedTypeId,
        categoryId: _selectedCategoryId,
        brandId: _selectedBrandId,
        uomSymbol: _uomSymbol,
        baseQuantity: double.tryParse(_baseQuantityController.text) ?? 1.0,
        defaultDiscountPercent:
            double.tryParse(_defaultDiscountController.text) ?? 0.0,
        defaultDiscountPercentLimit:
            double.tryParse(_discountLimitController.text) ?? 0.0,
        salesDiscountGlId: _selectedSalesDiscountGlId,
        organizationId: orgState.selectedOrganization?.id ?? 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      String? savedProductId;
      if (widget.productId == null) {
        final newProduct = await ref.read(productProvider.notifier).addProduct(product);
        savedProductId = newProduct?.id;
      } else {
        await ref.read(productProvider.notifier).updateProduct(product);
        savedProductId = widget.productId;
      }

      if (savedProductId != null && _isRecipe) {
        await _saveRecipe(savedProductId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product saved successfully')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final vendorState = ref.watch(vendorProvider);
    final accountingState = ref.watch(accountingProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadInitialData,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: _isLoading ? null : _saveProduct,
              icon: const Icon(Icons.check_circle_outline, size: 28),
              tooltip: 'Save Product',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                      children: [
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(
                                    'Basic Information', Icons.info_outline),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Product Name',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    prefixIcon:
                                        const Icon(Icons.shopping_bag_outlined),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _skuController,
                                  decoration: InputDecoration(
                                    labelText: 'SKU',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    prefixIcon:
                                        const Icon(Icons.qr_code_scanner),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    prefixIcon:
                                        const Icon(Icons.description_outlined),
                                    alignLabelWithHint: true,
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(
                                    'Classification', Icons.category_outlined),
                                const SizedBox(height: 20),
                                LookupField<ProductType, int>(
                                  label: 'Product Type *',
                                  value: _selectedTypeId,
                                  prefixIcon: Icons.merge_type,
                                  items: inventoryState.productTypes,
                                  hint: inventoryState.isLoading
                                      ? 'Loading...'
                                      : (inventoryState.productTypes.isEmpty
                                          ? 'No Product Types Found'
                                          : 'Select Product Type'),
                                  onChanged: (v) {
                                    setState(() => _selectedTypeId = v);
                                    final isNowRecipe = v != null &&
                                        inventoryState.productTypes
                                            .any((t) => t.id == v && t.name.toLowerCase() == 'recipe');
                                    if (isNowRecipe != _isRecipe) {
                                      setState(() {
                                        _isRecipe = isNowRecipe;
                                        if (!isNowRecipe) {
                                          _ingredients.clear();
                                          _recipeCost = 0.0;
                                        }
                                      });
                                    }
                                  },
                                  validator: (v) => v == null
                                      ? 'Please select a Product Type'
                                      : null,
                                  labelBuilder: (item) => item.name,
                                  valueBuilder: (item) => item.id,
                                  onAdd: (name) async {
                                    await ref
                                        .read(inventoryProvider.notifier)
                                        .addProductType(name);
                                    final newItem = ref
                                        .read(inventoryProvider)
                                        .productTypes
                                        .firstWhere((i) => i.name == name);
                                    setState(
                                        () => _selectedTypeId = newItem.id);
                                  },
                                ),
                                const SizedBox(height: 20),
                                LookupField<ProductCategory, int>(
                                  label: 'Category *',
                                  value: _selectedCategoryId,
                                  prefixIcon: Icons.category_outlined,
                                  items: inventoryState.categories,
                                  hint: inventoryState.isLoading
                                      ? 'Loading...'
                                      : (inventoryState.categories.isEmpty
                                          ? 'No Categories Found'
                                          : 'Select Category'),
                                  onChanged: (v) =>
                                      setState(() => _selectedCategoryId = v),
                                  validator: (v) => v == null
                                      ? 'Please select a Category'
                                      : null,
                                  labelBuilder: (item) => item.name,
                                  valueBuilder: (item) => item.id,
                                  onAdd: (name) async {
                                    await ref
                                        .read(inventoryProvider.notifier)
                                        .addCategory(name);
                                    final newItem = ref
                                        .read(inventoryProvider)
                                        .categories
                                        .firstWhere((i) => i.name == name);
                                    setState(
                                        () => _selectedCategoryId = newItem.id);
                                  },
                                ),
                                const SizedBox(height: 20),
                                LookupField<Brand, int>(
                                  label: 'Brand *',
                                  value: _selectedBrandId,
                                  prefixIcon: Icons.branding_watermark_outlined,
                                  items: inventoryState.brands,
                                  hint: inventoryState.isLoading
                                      ? 'Loading...'
                                      : (inventoryState.brands.isEmpty
                                          ? 'No Brands Found'
                                          : 'Select Brand'),
                                  onChanged: (v) =>
                                      setState(() => _selectedBrandId = v),
                                  validator: (v) => v == null
                                      ? 'Please select a Brand'
                                      : null,
                                  labelBuilder: (item) => item.name,
                                  valueBuilder: (item) => item.id,
                                  onAdd: (name) async {
                                    await ref
                                        .read(inventoryProvider.notifier)
                                        .addBrand(name);
                                    final newItem = ref
                                        .read(inventoryProvider)
                                        .brands
                                        .firstWhere((i) => i.name == name);
                                    setState(
                                        () => _selectedBrandId = newItem.id);
                                  },
                                ),
                                const SizedBox(height: 20),
                                LookupField<Vendor, String>(
                                  label: 'Preferred Supplier',
                                  value: _selectedBusinessPartnerId,
                                  prefixIcon: Icons.business_outlined,
                                  items: vendorState.suppliers,
                                  onChanged: (v) => setState(
                                      () => _selectedBusinessPartnerId = v),
                                  labelBuilder: (item) => item.name,
                                  valueBuilder: (item) => item.id,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_isRecipe) ...[
                          Card(
                            elevation: 2,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                      'Recipe / Ingredients', Icons.restaurant_outlined),
                                  const SizedBox(height: 20),
                                  if (_isRecipeLoading)
                                    const Center(child: CircularProgressIndicator())
                                  else ...[
                                    if (_ingredients.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: Text('No ingredients added yet. Tap + to add.'),
                                      )
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _ingredients.length,
                                        itemBuilder: (context, index) {
                                          final ingredient = _ingredients[index];
                                          final component = ref
                                              .read(productProvider)
                                              .products
                                              .firstWhereOrNull((p) => p.id == ingredient.componentProductId);
                                          final lineCost = component != null
                                              ? (ingredient.quantity * component.cost)
                                              : 0.0;

                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: LookupField<Product, String>(
                                                          label: 'Ingredient',
                                                          value: ingredient.componentProductId.isEmpty
                                                              ? null
                                                              : ingredient.componentProductId,
                                                          prefixIcon: Icons.shopping_basket_outlined,
                                                          items: ref.read(productProvider).products
                                                              .where((p) => p.id != widget.productId)
                                                              .toList(),
                                                          onChanged: (v) {
                                                            setState(() {
                                                              _ingredients[index] =
                                                                  ingredient.copyWith(componentProductId: v ?? '');
                                                            });
                                                          },
                                                          labelBuilder: (item) => item.name,
                                                          valueBuilder: (item) => item.id,
                                                          validator: (v) => v == null || v.isEmpty
                                                              ? 'Required'
                                                              : null,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.red),
                                                        onPressed: () => _removeIngredient(index),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextFormField(
                                                          decoration: const InputDecoration(
                                                            labelText: 'Quantity',
                                                            border: OutlineInputBorder(),
                                                          ),
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                          initialValue: ingredient.quantity == 0
                                                              ? ''
                                                              : ingredient.quantity.toString(),
                                                          onChanged: (value) {
                                                            final qty = double.tryParse(value) ?? 0.0;
                                                            setState(() {
                                                              _ingredients[index] =
                                                                  ingredient.copyWith(quantity: qty);
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: LookupField<UnitOfMeasure, int>(
                                                          label: 'UOM',
                                                          value: ingredient.uomId == 0
                                                              ? null
                                                              : ingredient.uomId,
                                                          prefixIcon: Icons.straighten_outlined,
                                                          items: inventoryState.unitsOfMeasure,
                                                          onChanged: (v) {
                                                            setState(() {
                                                              _ingredients[index] =
                                                                  ingredient.copyWith(uomId: v ?? 0);
                                                            });
                                                          },
                                                          labelBuilder: (item) => item.name,
                                                          valueBuilder: (item) => item.id,
                                                          validator: (v) => v == null || v == 0
                                                              ? 'Required'
                                                              : null,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextFormField(
                                                          decoration: const InputDecoration(
                                                            labelText: 'Wastage % (optional)',
                                                            border: OutlineInputBorder(),
                                                          ),
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                          initialValue: ingredient.wastagePercent == 0
                                                              ? ''
                                                              : ingredient.wastagePercent.toString(),
                                                          onChanged: (value) {
                                                            final wastage = double.tryParse(value) ?? 0.0;
                                                            setState(() {
                                                              _ingredients[index] =
                                                                  ingredient.copyWith(wastagePercent: wastage);
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(12),
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey.shade100,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                'Component Cost',
                                                                style: Theme.of(context).textTheme.bodySmall,
                                                              ),
                                                              Text(
                                                                 (component?.cost.toStringAsFixed(2) ?? '0.00'),
                                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Container(
                                                          padding: const EdgeInsets.all(12),
                                                          decoration: BoxDecoration(
                                                            color: Colors.indigo.shade50,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                'Line Cost',
                                                                style: Theme.of(context).textTheme.bodySmall,
                                                              ),
                                                              Text(
                                                                 lineCost.toStringAsFixed(2),
                                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                                      fontWeight: FontWeight.bold,
                                                                      color: Theme.of(context).primaryColor,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _addIngredient,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Ingredient'),
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Total Recipe Cost:',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                            Text(
                                               _recipeCost.toStringAsFixed(2),
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).primaryColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                              ],
                                ),
                              ),
                          ),
                          ],
                        const SizedBox(height: 20),
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Pricing & Inventory',
                                    Icons.inventory_2_outlined),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: LookupField<UnitOfMeasure, int>(
                                        label: 'Base Unit',
                                        value: _selectedUomId,
                                        prefixIcon: Icons.straighten_outlined,
                                        items: inventoryState.unitsOfMeasure,
                                        onChanged: (v) {
                                          final uom = inventoryState
                                              .unitsOfMeasure
                                              .firstWhere((u) => u.id == v);
                                          setState(() {
                                            _selectedUomId = v;
                                            _uomSymbol = uom.symbol;
                                          });
                                        },
                                        validator: (v) =>
                                            v == null ? 'Required' : null,
                                        labelBuilder: (item) =>
                                            '${item.name} (${item.symbol})',
                                        valueBuilder: (item) => item.id,
                                        onAdd: (name) async {
                                          await ref
                                              .read(inventoryProvider.notifier)
                                              .addUnitOfMeasureByName(name);
                                          final newItem = ref
                                              .read(inventoryProvider)
                                              .unitsOfMeasure
                                              .firstWhere((u) => u.name == name);
                                          setState(() {
                                            _selectedUomId = newItem.id;
                                            _uomSymbol = newItem.symbol;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _baseQuantityController,
                                        decoration: InputDecoration(
                                          labelText: 'Base Qty',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          hintText: 'e.g. 1.0',
                                        ),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Required';
                                          }
                                          if (double.tryParse(v) == null) {
                                            return 'Invalid';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _costController,
                                        decoration: InputDecoration(
                                          labelText: 'Cost Price',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          prefixIcon: const Icon(Icons
                                              .account_balance_wallet_outlined),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceController,
                                        decoration: InputDecoration(
                                          labelText: 'Sales Price',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          prefixIcon:
                                              const Icon(Icons.sell_outlined),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _limitPriceController,
                                        decoration: InputDecoration(
                                          labelText: 'Limit Price (Min)',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          hintText: 'Min Sales Price',
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v != null && v.isNotEmpty) {
                                            final limit =
                                                double.tryParse(v) ?? 0.0;
                                            if (_afterDiscountPrice <
                                                limit - 0.01) {
                                              return 'Must be ≤ After-Disc Price (${_afterDiscountPrice.toStringAsFixed(2)})';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _stockQtyController,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Opening Stock ${_uomSymbol != null ? '($_uomSymbol)' : ''}',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _defaultDiscountController,
                                        decoration: InputDecoration(
                                          labelText: 'Default Discount %',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          suffixText: '%',
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _discountLimitController,
                                        decoration: InputDecoration(
                                          labelText: 'Discount Limit %',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          suffixText: '%',
                                          helperText:
                                              'Limit: ${_afterDiscountPrice.toStringAsFixed(2)}',
                                          helperStyle: TextStyle(
                                            color: _afterDiscountPrice <
                                                    (double.tryParse(
                                                                _limitPriceController
                                                                    .text) ??
                                                            0.0) -
                                                        0.01
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v != null && v.isNotEmpty) {
                                            final limitPrice = double.tryParse(
                                                    _limitPriceController
                                                        .text) ??
                                                0.0;
                                            if (_afterDiscountPrice <
                                                limitPrice - 0.01) {
                                              return 'Price < Limit';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Accounting (GL Accounts)',
                                    Icons.account_balance_outlined),
                                if (accountingState.accounts.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                        '⚠️ No accounts loaded. Please refresh.',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold)),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                LookupField<ChartOfAccount, String>(
                                  label: 'Inventory Asset Account',
                                  value: _selectedInventoryGlId,
                                  prefixIcon: Icons.account_balance_outlined,
                                  items: _getFilteredAccounts(
                                      'Inventory', accountingState),
                                  onChanged: (v) => setState(
                                      () => _selectedInventoryGlId = v),
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                  labelBuilder: (item) =>
                                      '${item.accountCode} - ${item.accountTitle}',
                                  valueBuilder: (item) => item.id,
                                ),
                                const SizedBox(height: 20),
                                LookupField<ChartOfAccount, String>(
                                  label: 'COGS Account',
                                  value: _selectedCogsGlId,
                                  prefixIcon: Icons.account_tree_outlined,
                                  items: _getFilteredAccounts(
                                      'COGS', accountingState),
                                  onChanged: (v) =>
                                      setState(() => _selectedCogsGlId = v),
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                  labelBuilder: (item) =>
                                      '${item.accountCode} - ${item.accountTitle}',
                                  valueBuilder: (item) => item.id,
                                ),
                                const SizedBox(height: 20),
                                LookupField<ChartOfAccount, String>(
                                  label: 'Revenue/Sales Account',
                                  value: _selectedRevenueGlId,
                                  prefixIcon: Icons.monetization_on_outlined,
                                  items: _getFilteredAccounts(
                                      'BasicRevenue', accountingState),
                                  onChanged: (v) =>
                                      setState(() => _selectedRevenueGlId = v),
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                  labelBuilder: (item) =>
                                      '${item.accountCode} - ${item.accountTitle}',
                                  valueBuilder: (item) => item.id,
                                ),
                                const SizedBox(height: 20),
                                LookupField<ChartOfAccount, String>(
                                  label: 'Sales Discount Account',
                                  value: _selectedSalesDiscountGlId,
                                  prefixIcon: Icons.money_off_outlined,
                                  items: _getFilteredAccounts(
                                      'Discount', accountingState),
                                  onChanged: (v) => setState(
                                      () => _selectedSalesDiscountGlId = v),
                                  validator: (v) =>
                                      v == null ? 'Required' : null,
                                  labelBuilder: (item) =>
                                      '${item.accountCode} - ${item.accountTitle}',
                                  valueBuilder: (item) => item.id,
                                ),
                              ],
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
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.indigo, size: 22),
              const SizedBox(width: 10),
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                        letterSpacing: 0.5,
                      )),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.indigo.withValues(alpha: 0.2), thickness: 1),
        ],
      ),
    );
  }
}
