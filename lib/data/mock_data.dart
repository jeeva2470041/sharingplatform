import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/user_wallet.dart';

class MockData {
  /// Per-user wallets stored by userId
  static Map<String, UserWallet> _userWallets = {};

  /// Get current user's wallet (creates default if not exists)
  static UserWallet get userWallet {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    if (!_userWallets.containsKey(userId)) {
      _userWallets[userId] = UserWallet(balance: 1000.0, lockedDeposit: 0.0);
    }
    return _userWallets[userId]!;
  }

  /// Get wallet for a specific user (for lender settlements)
  static UserWallet getWalletForUser(String userId) {
    if (!_userWallets.containsKey(userId)) {
      _userWallets[userId] = UserWallet(balance: 1000.0, lockedDeposit: 0.0);
    }
    return _userWallets[userId]!;
  }

  /// Default item categories
  static List<String> categories = [
    'Electronics',
    'Books',
    'Calculators',
    'Notes',
    'Lab Equipment',
  ];

  /// All items in the platform (starts empty, users add items)
  static List<Item> allItems = [];

  /// Initialize data from SharedPreferences on app startup
  static Future<void> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getStringList('items') ?? [];
    allItems = itemsJson
        .map((item) => Item.fromJson(jsonDecode(item)))
        .toList();
  }

  /// Load categories from SharedPreferences
  static Future<void> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList('categories');
    if (savedCategories != null) {
      categories = savedCategories;
    }
  }

  /// Load all user wallets from SharedPreferences
  static Future<void> loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getString('user_wallets');
    if (walletsJson != null) {
      final Map<String, dynamic> data = jsonDecode(walletsJson);
      _userWallets = data.map((key, value) =>
          MapEntry(key, UserWallet.fromJson(value as Map<String, dynamic>)));
    }
  }

  /// Save items to SharedPreferences
  static Future<void> saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson =
        allItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('items', itemsJson);
  }

  /// Save all user wallets to SharedPreferences
  static Future<void> saveWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final walletsData = _userWallets.map((key, value) =>
        MapEntry(key, value.toJson()));
    await prefs.setString('user_wallets', jsonEncode(walletsData));
  }

  /// Save categories to SharedPreferences
  static Future<void> saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', categories);
  }

  /// Get items posted by current user (LENDER role)
  static List<Item> get myPostedItems {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    return allItems.where((item) => item.ownerId == currentUserId).toList();
  }

  /// Get items borrowed by current user (BORROWER role)
  static List<Item> get myBorrowedItems {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    return allItems.where((item) => item.borrowerId == currentUserId).toList();
  }

  /// Get items available in marketplace (excluding own items)
  static List<Item> get marketplaceItems {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    return allItems.where((item) => item.ownerId != currentUserId).toList();
  }
}
