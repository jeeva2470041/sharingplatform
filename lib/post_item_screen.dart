import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'data/mock_data.dart';
import 'models/item.dart';
import 'services/item_service.dart';
import 'app_theme.dart';

class PostItemScreen extends StatefulWidget {
  const PostItemScreen({super.key});

  @override
  State<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends State<PostItemScreen> {
  final _nameController = TextEditingController();
  final _depositController = TextEditingController();
  String _selectedCategory = MockData.categories.first;
  bool _isSubmitting = false; // Prevent double submission
  final List<Uint8List> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (_selectedImages.length < 3) {
          setState(() {
            _selectedImages.add(bytes);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppTheme.primary),
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.primary),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    // Prevent double submission
    if (_isSubmitting) return;

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter item name')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final currentUserId = user?.uid ?? 'unknown';
    final currentUserName = user?.displayName ?? user?.email?.split('@').first ?? 'Anonymous';

    final itemId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // Upload images first if any
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await ItemService.uploadItemImages(_selectedImages, itemId);
      }

      // Add new item to Firestore (shared across all users)
      final newItem = Item(
        id: itemId,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        deposit: _depositController.text.isEmpty
            ? '0'
            : _depositController.text.trim(),
        ownerId: currentUserId,
        ownerName: currentUserName,
        status: ItemStatus.available,
        createdAt: DateTime.now(),
        imageUrls: imageUrls,
      );

      await ItemService.addItem(newItem);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item added successfully')));

      // Use pop with result to safely navigate back
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Post New Item',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: AppTheme.fontWeightBold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryPressed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Item Details'),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              onChanged: (value) => setState(() {}),
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Item Name',
                                hintText: 'What are you sharing?',
                                prefixIcon: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppTheme.primary,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            const Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12.0,
                              runSpacing: 12.0,
                              children: [
                                ...MockData.categories.map((category) {
                                  final isSelected =
                                      _selectedCategory == category;
                                  return ChoiceChip(
                                    label: Text(
                                      category,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: AppTheme.primary,
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppTheme.primary
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedCategory = category;
                                        });
                                      }
                                    },
                                    showCheckmark: false,
                                    avatar: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: Colors.white,
                                          )
                                        : null,
                                  );
                                }),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  label: const Text(
                                    'New',
                                    style: TextStyle(color: AppTheme.primary),
                                  ),
                                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: AppTheme.primary.withOpacity(0.5),
                                    ),
                                  ),
                                  onPressed: _addCategory,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            TextField(
                              controller: _depositController,
                              onChanged: (value) => setState(() {}),
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Security Deposit (Optional)',
                                prefixText: '',
                                helperText: 'Amount locked during borrowing',
                                prefixIcon: const Icon(
                                  Icons.currency_rupee,
                                  color: AppTheme.primary,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Image picker section
                    _buildSectionHeader('Photos (Optional)'),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add up to 3 photos of your item',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  // Existing images
                                  ..._selectedImages.asMap().entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.memory(
                                              entry.value,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap: () => _removeImage(entry.key),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  // Add button
                                  if (_selectedImages.length < 3)
                                    GestureDetector(
                                      onTap: _showImageSourceDialog,
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              color: AppTheme.primary,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Add Photo',
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildSectionHeader('Preview'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _selectedCategory == 'Calculator'
                                ? Icons.calculate_outlined
                                : _selectedCategory == 'Notes'
                                ? Icons.notes_outlined
                                : Icons.menu_book_outlined,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          _nameController.text.isEmpty
                              ? 'Item Name'
                              : _nameController.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              _selectedCategory,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Deposit: ₹${_depositController.text.isEmpty ? '0' : _depositController.text}',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.success.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'Available',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Spacing for floating button
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Post Item',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
