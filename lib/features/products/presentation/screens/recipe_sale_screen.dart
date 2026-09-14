import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/presentation/providers/recipe_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';

class RecipeSaleScreen extends ConsumerStatefulWidget {
  const RecipeSaleScreen({super.key});

  @override
  ConsumerState<RecipeSaleScreen> createState() => _RecipeSaleScreenState();
}

class _RecipeSaleScreenState extends ConsumerState<RecipeSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _wastageControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts();
    });
  }

  List<Product> _getRecipeProducts() {
    final productState = ref.read(productProvider);
    return productState.products.where((p) => p.isRecipe).toList();
  }

  Future<void> _postSale() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final saleItems = <Map<String, dynamic>>[];
      final wastageMap = <String, double>{};

      for (var product in _getRecipeProducts()) {
        final qty = double.tryParse(_qtyControllers[product.id]?.text ?? '0') ?? 0.0;
        final wastage = double.tryParse(_wastageControllers[product.id]?.text ?? '0') ?? 0.0;

        if (qty > 0) {
          saleItems.add({
            'product_id': product.id,
            'quantity_sold': qty,
            'rate': product.rate,
          });
          if (wastage > 0) {
            wastageMap[product.id] = wastage;
          }
        }
      }

      if (saleItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter quantity for at least one product')),
          );
        }
        return;
      }

      await ref
          .read(recipeProvider.notifier)
          .postCounterSale(saleItems, wastageMap);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Counter sale posted successfully')),
        );
        for (var controller in _qtyControllers.values) {
          controller.clear();
        }
        for (var controller in _wastageControllers.values) {
          controller.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting sale: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipeProducts = _getRecipeProducts();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Counter Sale'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.post_add),
              onPressed: _postSale,
              tooltip: 'Post Sale',
            ),
        ],
      ),
      body: recipeProducts.isEmpty
          ? const Center(child: Text('No recipe products found'))
          : Form(
              key: _formKey,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recipeProducts.length,
                itemBuilder: (context, index) {
                  final product = recipeProducts[index];
                  final qtyController = _qtyControllers.putIfAbsent(product.id, () => TextEditingController());
                  final wastageController = _wastageControllers.putIfAbsent(product.id, () => TextEditingController());

                  final qty = double.tryParse(qtyController.text) ?? 0.0;
                  final rate = product.rate;
                  final sales = qty * rate;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: qtyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty Sold',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (value) => setState(() {}),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter qty';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: wastageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Wastage (optional)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoTile(
                                  label: 'Rate',
                                  value: rate.toStringAsFixed(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InfoTile(
                                  label: 'Sales',
                                  value: sales.toStringAsFixed(2),
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
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
