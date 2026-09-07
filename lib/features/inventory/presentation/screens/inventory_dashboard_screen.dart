import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InventoryDashboardScreen extends StatelessWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Operations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                title: 'Stock Transfers / Gate Pass',
                subtitle: 'Issue Gate Pass or Transfer Stock',
                icon: Icons.local_shipping,
                color: Colors.orange,
                onTap: () => context.push('/inventory/transfers'),
              ),
              const SizedBox(height: 24),
              Text(
                'Inventory Items',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                title: 'Products',
                subtitle: 'Manage inventory items',
                icon: Icons.inventory,
                color: Colors.blue,
                onTap: () => context.push('/products'),
              ),
              const SizedBox(height: 24),
              Text(
                'Products Setup',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                title: 'Brands',
                subtitle: 'Manage brands',
                icon: Icons.branding_watermark,
                color: Colors.teal,
                onTap: () => context.push('/inventory/brands'),
              ),
              const SizedBox(height: 8),
              _buildMenuCard(
                context,
                title: 'Categories',
                subtitle: 'Manage categories',
                icon: Icons.category,
                color: Colors.indigo,
                onTap: () => context.push('/inventory/categories'),
              ),
              const SizedBox(height: 8),
              _buildMenuCard(
                context,
                title: 'Product Types',
                subtitle: 'Manage types',
                icon: Icons.style,
                color: Colors.purple,
                onTap: () => context.push('/inventory/product-types'),
              ),
              const SizedBox(height: 8),
              _buildMenuCard(
                context,
                title: 'Units of Measure',
                subtitle: 'Manage UOMs',
                icon: Icons.scale,
                color: Colors.brown,
                onTap: () => context.push('/inventory/units-of-measure'),
              ),
              const SizedBox(height: 8),
              _buildMenuCard(
                context,
                title: 'Unit Conversions',
                subtitle: 'Manage conversions',
                icon: Icons.transform,
                color: Colors.deepOrange,
                onTap: () => context.push('/inventory/unit-conversions'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
