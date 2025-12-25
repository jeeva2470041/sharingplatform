import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/user_wallet.dart';

class MockData {
  static const String lenderId = 'lender_user';
  static const String borrowerId = 'borrower_user';
  static String currentUserId = borrowerId; // Start as borrower

  static final UserWallet userWallet = UserWallet(
    balance: 1000.0,
    lockedDeposit: 0.0,
  );

  static List<Item> allItems = _getDefaultItems();
  static List<String> categories = ['Electronics', 'Book', 'Calculator', 'Notes'];

  static List<Item> _getDefaultItems() {
    return [
      Item(
        id: '1',
        name: 'Mechanical Keyboard',
        category: 'Electronics',
        deposit: '25',
        ownerId: lenderId, // Owned by the lender
        status: ItemStatus.requested,
        requestedBy: borrowerId, // Requested by the borrower
      ),
      Item(
        id: '2',
        name: 'Data Structures Textbook',
        category: 'Book',
        deposit: '10',
        ownerId: lenderId, // Owned by the lender
        status: ItemStatus.available,
      ),
      Item(
        id: '3',
        name: 'Scientific Calculator',
        category: 'Calculator',
        deposit: '15',
        ownerId: 'another_user',
        status: ItemStatus.available,
      ),
      Item(
        id: '4',
        name: 'Old Class Notes',
        category: 'Notes',
        deposit: '0',
        ownerId: borrowerId, // Owned by the borrower
        status: ItemStatus.available,
      ),
    ];
  }

  static Future<void> resetData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('items');
    await prefs.remove('wallet');
    await prefs.remove('categories');
    
    allItems = _getDefaultItems();
    categories = ['Electronics', 'Book', 'Calculator', 'Notes'];
    currentUserId = borrowerId; // Reset to borrower
    userWallet.balance = 1000.0;
    userWallet.lockedDeposit = 0.0;
    
    await saveItems();
    await saveWallet();
    await saveCategories();
  }

  static Future<void> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Categories
    final String? categoriesJson = prefs.getString('categories');
    if (categoriesJson != null) {
      categories = List<String>.from(jsonDecode(categoriesJson));
    } else {
      await saveCategories();
    }

    // Load Items
    final String? itemsJson = prefs.getString('items');
    if (itemsJson != null) {
      final List<dynamic> decodedList = jsonDecode(itemsJson);
      allItems = decodedList.map((item) => Item.fromJson(item)).toList();
    } else {
      // Save initial mock data if nothing saved yet
      await saveItems();
    }

    // Load Wallet
    final String? walletJson = prefs.getString('wallet');
    if (walletJson != null) {
      final Map<String, dynamic> walletMap = jsonDecode(walletJson);
      userWallet.balance = (walletMap['balance'] as num).toDouble();
      userWallet.lockedDeposit = (walletMap['lockedDeposit'] as num).toDouble();
    } else {
      await saveWallet();
    }
  }

  static Future<void> saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = jsonEncode(allItems.map((e) => e.toJson()).toList());
    await prefs.setString('items', itemsJson);
  }

  static Future<void> saveWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final String walletJson = jsonEncode(userWallet.toJson());
    await prefs.setString('wallet', walletJson);
  }

  static Future<void> saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String categoriesJson = jsonEncode(categories);
    await prefs.setString('categories', categoriesJson);
  }

  static List<Item> get myPostedItems =>
      allItems.where((item) => item.ownerId == currentUserId).toList();

  static List<Item> get myRequestedItems =>
      allItems.where((item) => item.requestedBy == currentUserId).toList();

  static List<Item> get marketplaceItems =>
      allItems.where((item) => item.ownerId != currentUserId).toList();
}
