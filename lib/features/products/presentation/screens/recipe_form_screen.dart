import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:ordermate/features/products/presentation/providers/recipe_provider.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class RecipeFormScreen extends ConsumerStatefulWidget {
  const RecipeFormScreen({super.key, required this.product});
  final Product product;

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<ProductRecipe> _ingredients = [];
  bool _isLoading = false;
  double _recipeCost = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recipeProvider.notifier).loadRecipes(widget.product.id);
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        ref.read(inventoryProvider.notifier).loadAll(),
        ref.read(productProvider.notifier).loadProducts(),
      ]);
      final recipes = await ref
          .read(recipeProvider.notifier)
          .calculateRecipeCost(widget.product.id);
      setState(() {
        _recipeCost = recipes;
      });
    } catch (e) {
      debugPrint('RecipeForm: Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(ProductRecipe(
        id: '',
        productId: widget.product.id,
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

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(recipeProvider.notifier)
          .saveRecipe(widget.product.id, _ingredients);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recipe: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final productState = ref.watch(productProvider);
    final products = productState.products.where((p) => p.id != widget.product.id).toList();
    final uoms = inventoryState.unitsOfMeasure;

    return Scaffold(
      appBar: AppBar(
        title: Text('Recipe: ${widget.product.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveRecipe,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Recipe Cost:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                           _recipeCost.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ingredients.length,
                      itemBuilder: (context, index) {
                        final ingredient = _ingredients[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                          labelText: 'Ingredient',
                                          border: OutlineInputBorder(),
                                        ),
                                        value: ingredient.componentProductId.isEmpty
                                            ? null
                                            : ingredient.componentProductId,
                                        items: products
                                            .map((p) => DropdownMenuItem(
                                                  value: p.id,
                                                  child: Text('${p.name} (${p.uomSymbol})'),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _ingredients[index] =
                                                ingredient.copyWith(componentProductId: value ?? '');
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please select an ingredient';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
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
                                        validator: (value) {
                                          if (value == null || value.isEmpty || double.tryParse(value) == null) {
                                            return 'Enter valid qty';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        decoration: const InputDecoration(
                                          labelText: 'UOM',
                                          border: OutlineInputBorder(),
                                        ),
                                        value: ingredient.uomId == 0 ? null : ingredient.uomId,
                                        items: uoms
                                            .map((uom) => DropdownMenuItem(
                                                  value: uom.id,
                                                  child: Text('${uom.name} (${uom.symbol})'),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _ingredients[index] =
                                                ingredient.copyWith(uomId: value ?? 0);
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value == 0) {
                                            return 'Select UOM';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Wastage % (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIngredient,
        child: const Icon(Icons.add),
      ),
    );
  }
}
