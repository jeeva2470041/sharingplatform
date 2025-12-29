import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// Utility to seed the Firestore database with sample items
/// Run this once to populate the database with initial data
class SeedDatabase {
  static final _firestore = FirebaseFirestore.instance;
  static final _itemsCollection = _firestore.collection('items');

  /// Sample items for the sharing platform
  /// These represent items that college students might share
  static List<Map<String, dynamic>> get sampleItems => [
    {
      'id': 'item_calc_001',
      'name': 'Casio FX-991ES Scientific Calculator',
      'category': 'Calculators',
      'deposit': '200',
      'ownerId': 'sample_user_1',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.5,
      'ratingCount': 12,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_book_001',
      'name': 'Data Structures and Algorithms - Cormen',
      'category': 'Books',
      'deposit': '150',
      'ownerId': 'sample_user_1',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.8,
      'ratingCount': 25,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_elec_001',
      'name': 'Arduino Uno Starter Kit',
      'category': 'Electronics',
      'deposit': '500',
      'ownerId': 'sample_user_2',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.2,
      'ratingCount': 8,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_elec_002',
      'name': 'Raspberry Pi 4 Model B',
      'category': 'Electronics',
      'deposit': '800',
      'ownerId': 'sample_user_2',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.9,
      'ratingCount': 15,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_notes_001',
      'name': 'Computer Networks Complete Notes - Anna University',
      'category': 'Notes',
      'deposit': '50',
      'ownerId': 'sample_user_3',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.7,
      'ratingCount': 32,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_lab_001',
      'name': 'Digital Multimeter (Fluke)',
      'category': 'Lab Equipment',
      'deposit': '300',
      'ownerId': 'sample_user_3',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.4,
      'ratingCount': 6,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_book_002',
      'name': 'Database Management Systems - Navathe',
      'category': 'Books',
      'deposit': '180',
      'ownerId': 'sample_user_1',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.6,
      'ratingCount': 19,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_calc_002',
      'name': 'Texas Instruments TI-84 Plus',
      'category': 'Calculators',
      'deposit': '350',
      'ownerId': 'sample_user_2',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.3,
      'ratingCount': 10,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_elec_003',
      'name': 'USB Oscilloscope (Hantek)',
      'category': 'Electronics',
      'deposit': '600',
      'ownerId': 'sample_user_3',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.1,
      'ratingCount': 4,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_notes_002',
      'name': 'Machine Learning Handwritten Notes',
      'category': 'Notes',
      'deposit': '75',
      'ownerId': 'sample_user_1',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.9,
      'ratingCount': 45,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_book_003',
      'name': 'Operating System Concepts - Galvin',
      'category': 'Books',
      'deposit': '160',
      'ownerId': 'sample_user_2',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.5,
      'ratingCount': 22,
      'createdAt': Timestamp.now(),
    },
    {
      'id': 'item_lab_002',
      'name': 'Breadboard + Jumper Wires Kit',
      'category': 'Lab Equipment',
      'deposit': '100',
      'ownerId': 'sample_user_1',
      'status': ItemStatus.available.index,
      'borrowerId': null,
      'rating': 4.0,
      'ratingCount': 14,
      'createdAt': Timestamp.now(),
    },
  ];

  /// Seed the database with sample items
  /// Overwrites existing items with same IDs
  static Future<void> seedItems() async {
    final batch = _firestore.batch();
    
    for (final item in sampleItems) {
      final docRef = _itemsCollection.doc(item['id']);
      batch.set(docRef, item);
    }
    
    await batch.commit();
    print('✅ Database seeded with ${sampleItems.length} items');
  }

  /// Clear all items from the database
  static Future<void> clearItems() async {
    final snapshot = await _itemsCollection.get();
    final batch = _firestore.batch();
    
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    print('🗑️ All items cleared from database');
  }

  /// Seed items for a specific user (use actual Firebase UID)
  /// This creates items owned by the logged-in user
  static Future<void> seedItemsForUser(String userId) async {
    final userItems = [
      {
        'id': 'user_item_${DateTime.now().millisecondsSinceEpoch}_1',
        'name': 'My Scientific Calculator',
        'category': 'Calculators',
        'deposit': '200',
        'ownerId': userId,
        'status': ItemStatus.available.index,
        'borrowerId': null,
        'rating': null,
        'ratingCount': null,
        'createdAt': Timestamp.now(),
      },
      {
        'id': 'user_item_${DateTime.now().millisecondsSinceEpoch}_2',
        'name': 'DSA Textbook',
        'category': 'Books',
        'deposit': '150',
        'ownerId': userId,
        'status': ItemStatus.available.index,
        'borrowerId': null,
        'rating': null,
        'ratingCount': null,
        'createdAt': Timestamp.now(),
      },
    ];

    final batch = _firestore.batch();
    for (final item in userItems) {
      final docRef = _itemsCollection.doc(item['id']);
      batch.set(docRef, item);
    }
    
    await batch.commit();
    print('✅ Added ${userItems.length} items for user: $userId');
  }
}
