
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data_model/Category_entity.dart';

class CategoryDatabase {
  CategoryDatabase._();

  static final CategoryDatabase instance = CategoryDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();

    _database = await openDatabase(
      p.join(dbPath, 'trackflow_categories.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createCategoriesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE categories RENAME TO categories_v1',
          );

          await _createCategoriesTable(db);

          await db.execute('''
            INSERT INTO categories (
              userId,
              id,
              name,
              taskCount,
              categoryColor,
              categoryBackgroundColor,
              categoryIcon
            )
            SELECT
              '',
              id,
              name,
              taskCount,
              categoryColor,
              categoryBackgroundColor,
              categoryIcon
            FROM categories_v1
          ''');

          await db.execute('DROP TABLE categories_v1');
        }
      },
    );

    return _database!;
  }

  Future<void> _createCategoriesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE categories (
        userId TEXT NOT NULL,
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        taskCount INTEGER NOT NULL,
        categoryColor INTEGER NOT NULL,
        categoryBackgroundColor INTEGER NOT NULL,
        categoryIcon INTEGER NOT NULL,
        PRIMARY KEY (userId, id)
      )
    ''');
  }

  // Existing categories ko correct account se assign karo.
  Future<void> ensureLegacyDataAssigned(String userId) async {
    final db = await database;

    await db.update(
      'categories',
      {'userId': userId},
      where: "userId = ''",
    );
  }

  Future<List<CategoryEntity>> getCategories({
    required String userId,
  }) async {
    final db = await database;

    final rows = await db.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map((row) {
      final colorValue = row['categoryColor'] as int;
      final backgroundValue =
      row['categoryBackgroundColor'] as int;
      final iconValue = row['categoryIcon'] as int;

      return CategoryEntity(
        id: row['id'] as String,
        name: row['name'] as String,
        taskCount: row['taskCount'] as int,
        categoryColor: colorValue,
        categoryBackgroundColor: backgroundValue,
        categoryIcon: iconValue,
        color: Color(colorValue),
        backgroundColor: Color(backgroundValue),
        icon: IconData(
          iconValue,
          fontFamily: 'MaterialIcons',
        ),
      );
    }).toList();
  }

  Future<void> saveCategory(
      CategoryEntity category, {
        required String userId,
      }) async {
    final db = await database;

    await db.insert(
      'categories',
      {
        'userId': userId,
        'id': category.id,
        'name': category.name,
        'taskCount': category.taskCount,
        'categoryColor': category.categoryColor,
        'categoryBackgroundColor':
        category.categoryBackgroundColor,
        'categoryIcon': category.categoryIcon,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAllCategories(
      List<CategoryEntity> categories, {
        required String userId,
      }) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final category in categories) {
        await txn.insert(
          'categories',
          {
            'userId': userId,
            'id': category.id,
            'name': category.name,
            'taskCount': category.taskCount,
            'categoryColor': category.categoryColor,
            'categoryBackgroundColor':
            category.categoryBackgroundColor,
            'categoryIcon': category.categoryIcon,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteCategory(
      String id, {
        required String userId,
      }) async {
    final db = await database;

    await db.delete(
      'categories',
      where: 'userId = ? AND id = ?',
      whereArgs: [userId, id],
    );
  }

  // Sirf current account ki categories clear hongi.
  Future<void> clearCategories({
    required String userId,
  }) async {
    final db = await database;

    await db.delete(
      'categories',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<void> clearUserCategories(String userId) async {
    await clearCategories(userId: userId);
  }
}
