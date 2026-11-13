
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data_model/Category_entity.dart';
import '../../Add_dummy_data/add_dummy_category.dart';
import '../database/category_database.dart';

final categoryProvider =
NotifierProvider<CategoryNotifier, List<CategoryEntity>>(
  CategoryNotifier.new,
);

class CategoryNotifier extends Notifier<List<CategoryEntity>> {
  late Future<void> _ready;

  String? _userId;

  String get _requireUserId {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('User is not logged in.');
    }

    return uid;
  }

  @override
  List<CategoryEntity> build() {
    _userId = FirebaseAuth.instance.currentUser?.uid;

    if (_userId == null) {
      _ready = Future.value();
      return [...dummyCategories];
    }

    _ready = _loadCategories(_userId!);

    return [...dummyCategories];
  }

  Future<void> _loadCategories(String uid) async {
    final db = CategoryDatabase.instance;

    // Existing categories current Firebase account ki hain.
    await db.ensureLegacyDataAssigned(uid);

    var savedCategories = await db.getCategories(
      userId: uid,
    );

    // First installation: save default categories.
    if (savedCategories.isEmpty) {
      await db.saveAllCategories(
        dummyCategories,
        userId: uid,
      );

      savedCategories = await db.getCategories(
        userId: uid,
      );
    }

    if (_userId != uid) return;

    state = savedCategories;
  }

  Future<void> addCategory(CategoryEntity category) async {
    await _ready;

    final uid = _requireUserId;

    await CategoryDatabase.instance.saveCategory(
      category,
      userId: uid,
    );

    state = [...state, category];
  }

  Future<void> deleteCategory(String id) async {
    await _ready;

    final uid = _requireUserId;

    await CategoryDatabase.instance.deleteCategory(
      id,
      userId: uid,
    );

    state = state.where((category) {
      return category.id != id;
    }).toList();
  }

  Future<void> updateCategory(
      CategoryEntity updatedCategory,
      ) async {
    await _ready;

    final uid = _requireUserId;

    await CategoryDatabase.instance.saveCategory(
      updatedCategory,
      userId: uid,
    );

    state = [
      for (final category in state)
        if (category.id == updatedCategory.id)
          updatedCategory
        else
          category,
    ];
  }
}
