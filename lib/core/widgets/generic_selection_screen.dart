import 'package:flutter/material.dart';

class GenericSelectionScreen<T> extends StatefulWidget {
  const GenericSelectionScreen({
    required this.title,
    required this.items,
    required this.labelBuilder,
    super.key,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;

  @override
  State<GenericSelectionScreen<T>> createState() =>
      _GenericSelectionScreenState<T>();
}

class _GenericSelectionScreenState<T> extends State<GenericSelectionScreen<T>> {
  late List<T> _filteredItems;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filterItems(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredItems = widget.items;
      });
      return;
    }

    setState(() {
      _filteredItems = widget.items
          .where(
            (item) => widget
                .labelBuilder(item)
                .toLowerCase()
                .contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor,
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon:
                    Icon(Icons.search, color: Theme.of(context).primaryColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return ListTile(
                  title: Text(widget.labelBuilder(item)),
                  onTap: () {
                    Navigator.pop(context, item);
                  },
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
