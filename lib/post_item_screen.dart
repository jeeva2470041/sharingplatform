import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data/mock_data.dart';
import 'models/item.dart';

class PostItemScreen extends StatefulWidget {
  const PostItemScreen({super.key});

  @override
  State<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends State<PostItemScreen> {
  final _nameController = TextEditingController();
  final _depositController = TextEditingController();
  String _selectedCategory = MockData.categories.first;

  @override
  void initState() {
    super.initState();
    if (!MockData.categories.contains(_selectedCategory)) {
      _selectedCategory = MockData.categories.first;
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Lab Coat',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCategory != null && !MockData.categories.contains(newCategory)) {
      setState(() {
        MockData.categories.add(newCategory);
        _selectedCategory = newCategory;
      });
      await MockData.saveCategories();
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter item name')));
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    // Add new item to shared list
    final newItem = Item(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      category: _selectedCategory,
      deposit: _depositController.text.isEmpty ? '0' : _depositController.text,
      ownerId: currentUserId,
      status: ItemStatus.available,
    );

    MockData.allItems.add(newItem);
    await MockData.saveItems();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Item added successfully')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Item')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Item Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameController,
                        onChanged: (value) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                          hintText: 'e.g., Casio Calculator',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          ...MockData.categories.map((category) {
                            return ChoiceChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                }
                              },
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 16),
                            label: const Text('Add Category'),
                            onPressed: _addCategory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _depositController,
                        onChanged: (value) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Deposit Amount',
                          prefixText: '\$ ',
                          hintText: 'Optional security deposit',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: Icon(
                      _selectedCategory == 'Calculator'
                          ? Icons.calculate_outlined
                          : _selectedCategory == 'Notes'
                          ? Icons.notes_outlined
                          : Icons.menu_book_outlined,
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(
                    _nameController.text.isEmpty
                        ? 'Item Name'
                        : _nameController.text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Deposit: \$${_depositController.text.isEmpty ? '0' : _depositController.text}',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: const Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Item',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
