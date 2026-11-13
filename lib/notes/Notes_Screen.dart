
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../Add_dummy_data/add_dummy_category_store.dart';
import '../data_model/Category_entity.dart';
import 'note_database/database.dart';
import 'notes_data_model/notes_data_model.dart';
import 'note_database/notes_sync_controller.dart';
import '../features/pdf_viewer_screen.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen>  with WidgetsBindingObserver{
  static const Color _primaryColor = Color(0xFF5146E5);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  // account delete

  bool _isSyncing = false;


  final TextEditingController _searchController = TextEditingController();

  final List<NoteFolder> _folders = [];
  final List<NoteItem> _notes = [];

  late List<CategoryEntity> categories;
  CategoryEntity? selectedCategory;

  String? _selectedFolderId;
  String _selectedCategory = 'All Notes';
  String _searchQuery = '';

  bool _isLoading = true;
  int _nextId = 1;

  String? get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid;


  CollectionReference<Map<String, dynamic>>? get _folderCollection {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('noteFolders');
  }

  CollectionReference<Map<String, dynamic>>? get _noteCollection {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notes');
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    categories = List<CategoryEntity>.from(sharedCategories);

    if (categories.isNotEmpty) {
      selectedCategory = categories.first;
    }

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
          if (NotesSyncController.instance.isPaused) return;

          if (results.any((result) => result != ConnectivityResult.none)) {
            _syncWithFirestore();
          }
        });

    _loadLocalData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !NotesSyncController.instance.isPaused) {
      _syncWithFirestore();
    }
  }
  String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_nextId++}';


  Future<void> _loadLocalData() async {
    try {
      final uid = _currentUserId;

      if (uid == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Existing local records ko current account se assign karo.
      await NotesDatabase.instance.ensureLegacyDataAssigned(uid);

      final folders = await NotesDatabase.instance.getFolders(
        userId: uid,
      );

      final notes = await NotesDatabase.instance.getNotes(
        userId: uid,
      );

      if (!mounted || _currentUserId != uid) return;

      setState(() {
        _folders
          ..clear()
          ..addAll(folders);

        _notes
          ..clear()
          ..addAll(notes);

        _isLoading = false;
      });

      await _syncWithFirestore();
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load notes: $error')),
      );
    }
  }
  // ------------------------------------------------------------
  // FIRESTORE SYNC
  // ------------------------------------------------------------
// ye delete

  Future<void> _syncWithFirestore() async {
    final controller = NotesSyncController.instance;

    if (controller.isPaused || _isSyncing) return;

    final uid = _currentUserId;
    if (uid == null) return;

    await controller.runSync(() async {
      if (controller.isPaused || _isSyncing) return;
      if (_currentUserId != uid) return;

      final folderCollection = _folderCollection;
      final noteCollection = _noteCollection;

      if (folderCollection == null || noteCollection == null) return;

      _isSyncing = true;

      try {
        await NotesDatabase.instance.ensureLegacyDataAssigned(uid);

        // 1. Upload pending local changes.
        final pendingItems =
        await NotesDatabase.instance.getPendingSyncItems(
          userId: uid,
        );

        for (final item in pendingItems) {
          if (controller.isPaused || _currentUserId != uid) return;

          final collection = item.entityType == 'folder'
              ? folderCollection
              : noteCollection;

          final document = collection.doc(item.entityId);

          if (item.action == 'delete') {
            await document.delete().timeout(
              const Duration(seconds: 12),
            );
          } else {
            final payload = Map<String, dynamic>.from(item.payload);

            if (item.entityType == 'note') {
              payload.remove('pdfPath');
            }

            await document.set(payload).timeout(
              const Duration(seconds: 12),
            );
          }

          await NotesDatabase.instance.removePendingSyncItem(
            item.id,
            userId: uid,
          );
        }

        if (controller.isPaused || _currentUserId != uid) return;

        // 2. Fetch remote data.
        final remoteFolders = await folderCollection.get();
        final remoteNotes = await noteCollection.get();

        final remoteFolderIds =
        remoteFolders.docs.map((doc) => doc.id).toSet();

        final remoteNoteIds =
        remoteNotes.docs.map((doc) => doc.id).toSet();

        // 3. Upload older local folders missing in Firestore.
        for (final folder in List<NoteFolder>.from(_folders)) {
          if (!remoteFolderIds.contains(folder.id)) {
            await NotesDatabase.instance.queueFolderUpload(
              folder,
              userId: uid,
            );
          }
        }

        // 4. Upload older local notes missing in Firestore.
        for (final note in List<NoteItem>.from(_notes)) {
          if (!remoteNoteIds.contains(note.id)) {
            await NotesDatabase.instance.queueNoteUpload(
              note,
              userId: uid,
            );
          }
        }

        // 5. Process migrated records.
        final migrationItems =
        await NotesDatabase.instance.getPendingSyncItems(
          userId: uid,
        );

        for (final item in migrationItems) {
          if (controller.isPaused || _currentUserId != uid) return;

          final collection = item.entityType == 'folder'
              ? folderCollection
              : noteCollection;

          final document = collection.doc(item.entityId);

          if (item.action == 'delete') {
            await document.delete().timeout(
              const Duration(seconds: 12),
            );
          } else {
            final payload = Map<String, dynamic>.from(item.payload);

            if (item.entityType == 'note') {
              payload.remove('pdfPath');
            }

            await document.set(payload).timeout(
              const Duration(seconds: 12),
            );
          }

          await NotesDatabase.instance.removePendingSyncItem(
            item.id,
            userId: uid,
          );
        }

        if (controller.isPaused || _currentUserId != uid) return;

        // 6. Download missing folders.
        final localFolderIds = _folders.map((e) => e.id).toSet();

        for (final doc in remoteFolders.docs) {
          if (!localFolderIds.contains(doc.id)) {
            final folder = NoteFolder.fromMap({
              ...doc.data(),
              'id': doc.id,
            });

            await NotesDatabase.instance.insertFolder(
              folder,
              userId: uid,
            );

            _folders.add(folder);
          }
        }

        // 7. Download missing notes and update newer remote notes.
        final localNoteMap = {
          for (final note in _notes) note.id: note,
        };

        for (final doc in remoteNotes.docs) {
          final localNote = localNoteMap[doc.id];

          final remoteNote = NoteItem.fromMap({
            ...doc.data(),
            'id': doc.id,
            'pdfPath': localNote?.pdfPath,
          });

          if (localNote == null) {
            await NotesDatabase.instance.insertNote(
              remoteNote,
              userId: uid,
            );

            _notes.add(remoteNote);
          } else if (remoteNote.updatedAt.isAfter(localNote.updatedAt)) {
            remoteNote.pdfPath = localNote.pdfPath;

            await NotesDatabase.instance.updateNote(
              remoteNote,
              userId: uid,
            );

            final index = _notes.indexWhere((e) => e.id == doc.id);

            if (index != -1) {
              _notes[index] = remoteNote;
            }
          }
        }

        if (mounted && _currentUserId == uid) {
          setState(() {});
        }
      } catch (error) {
        debugPrint('Notes Firestore sync error: $error');
      } finally {
        _isSyncing = false;
      }
    });
  }
// ider tak
  Future<void> _showFolderDialog({NoteFolder? folder}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        initialName: folder?.name ?? '',
        isRename: folder != null,
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    final uid = _currentUserId;
    if (uid == null) return;

    if (folder == null) {
      final newFolder = NoteFolder(
        id: _generateId(),
        name: result.trim(),
        parentId: _selectedFolderId,
      );

      final saved = await NotesSyncController.instance.runOperation(() async {
        await NotesDatabase.instance.saveFolderAndQueue(
          newFolder,
          userId: uid,
        );
      });

      if (!saved || !mounted || _currentUserId != uid) return;

      setState(() {
        _folders.add(newFolder);
      });
    } else {
      folder.name = result.trim();

      final saved = await NotesSyncController.instance.runOperation(() async {
        await NotesDatabase.instance.saveFolderAndQueue(
          folder,
          userId: uid,
        );
      });

      if (!saved || !mounted || _currentUserId != uid) return;

      setState(() {});
    }

    _syncWithFirestore();
  }

  Future<void> _confirmDeleteFolder(NoteFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "${folder.name}" and all its subfolders and notes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final deleted = await NotesSyncController.instance.runOperation(() async {
      await _deleteFolderRecursively(folder.id);
    });

    if (!deleted || !mounted) return;

    _syncWithFirestore();

    setState(() {
      if (_selectedFolderId == folder.id ||
          !_folders.any((item) => item.id == _selectedFolderId)) {
        _selectedFolderId = folder.parentId;
      }
    });
  }

  Future<void> _deleteFolderRecursively(String folderId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final childFolderIds = _folders
        .where((folder) => folder.parentId == folderId)
        .map((folder) => folder.id)
        .toList();

    for (final childId in childFolderIds) {
      await _deleteFolderRecursively(childId);
    }

    final folderNotes = _notes
        .where((note) => note.folderId == folderId)
        .toList();

    for (final note in folderNotes) {
      await NotesDatabase.instance.deleteNoteAndQueue(
        note.id,
        userId: uid,
      );

      await _deleteLocalPdf(note.pdfPath);
    }

    await NotesDatabase.instance.deleteFolderAndQueue(
      folderId,
      userId: uid,
    );

    _notes.removeWhere((note) => note.folderId == folderId);
    _folders.removeWhere((folder) => folder.id == folderId);
  }

  Future<void> _openNoteEditor({NoteItem? note}) async {
    final result = await showModalBottomSheet<NoteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => NoteEditorSheet(
        initialNote: note,
        categories: _categories.where((c) => c != 'All Notes').toList(),
      ),
    );

    if (!mounted || result == null) return;

    final uid = _currentUserId;
    if (uid == null) return;

    final saved = await NotesSyncController.instance.runOperation(() async {
      if (note == null) {
        final newNote = NoteItem(
          id: _generateId(),
          title: result.title,
          content: result.content,
          category: result.category,
          folderId: _selectedFolderId,
          pdfName: result.pdfName,
          pdfPath: result.pdfPath,
          updatedAt: DateTime.now(),
        );

        await NotesDatabase.instance.saveNoteAndQueue(
          newNote,
          userId: uid,
        );

        if (mounted && _currentUserId == uid) {
          setState(() {
            _notes.add(newNote);
          });
        }
      } else {
        final oldPdfPath = note.pdfPath;

        note.title = result.title;
        note.content = result.content;
        note.category = result.category;
        note.pdfName = result.pdfName;
        note.pdfPath = result.pdfPath;
        note.updatedAt = DateTime.now();

        await NotesDatabase.instance.saveNoteAndQueue(
          note,
          userId: uid,
        );

        if (oldPdfPath != note.pdfPath) {
          await _deleteLocalPdf(oldPdfPath);
        }

        if (mounted && _currentUserId == uid) {
          setState(() {});
        }
      }
    });

    if (!saved || !mounted || _currentUserId != uid) return;

    _syncWithFirestore();
  }

  Future<void> _confirmDeleteNote(NoteItem note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          'Are you sure you want to delete "${note.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = _currentUserId;
    if (uid == null) return;

    final deleted = await NotesSyncController.instance.runOperation(() async {
      await NotesDatabase.instance.deleteNoteAndQueue(
        note.id,
        userId: uid,
      );

      await _deleteLocalPdf(note.pdfPath);
    });

    if (!deleted || !mounted || _currentUserId != uid) return;

    setState(() {
      _notes.removeWhere((item) => item.id == note.id);
    });

    _syncWithFirestore();
  }






  //ider tak

  // ------------------------------------------------------------
  // PDF LOCAL STORAGE
  // ------------------------------------------------------------



  Future<void> _deleteLocalPdf(String? pdfPath) async {
    if (pdfPath == null || pdfPath.isEmpty) return;

    try {
      final file = File(pdfPath);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('PDF delete error: $error');
    }
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  NoteFolder? get _currentFolder {
    if (_selectedFolderId == null) return null;

    for (final folder in _folders) {
      if (folder.id == _selectedFolderId) return folder;
    }

    return null;
  }

  List<NoteFolder> get _visibleFolders {
    return _folders
        .where((folder) => folder.parentId == _selectedFolderId)
        .toList();
  }

  List<NoteItem> get _visibleNotes {
    return _notes.where((note) {
      final matchesFolder = note.folderId == _selectedFolderId;

      final matchesCategory = _selectedCategory == 'All Notes' ||
          note.category == _selectedCategory;

      final query = _searchQuery.toLowerCase();

      final matchesSearch = query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);

      return matchesFolder && matchesCategory && matchesSearch;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<String> get _categories => [
    'All Notes',
    ...sharedCategories.map((category) => category.name),
  ];

  int _noteCountForFolder(String folderId) {
    return _notes.where((note) => note.folderId == folderId).length;
  }

  // ------------------------------------------------------------
  // FOLDER ACTIONS
  // ------------------------------------------------------------



  void _openFolder(NoteFolder folder) {
    setState(() {
      _selectedFolderId = folder.id;
      _selectedCategory = 'All Notes';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _navigateUp() {
    final currentFolder = _currentFolder;

    setState(() {
      _selectedFolderId = currentFolder?.parentId;
      _selectedCategory = 'All Notes';
      _searchQuery = '';
      _searchController.clear();
    });
  }


  // ------------------------------------------------------------
  // NOTE ACTIONS
  // ------------------------------------------------------------


  // ------------------------------------------------------------
  // MAIN UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _selectedFolderId == null
            ? null
            : IconButton(
          onPressed: _navigateUp,
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
        ),
        title: Text(
          _currentFolder?.name ?? 'My Notes',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create folder',
            onPressed: () => _showFolderDialog(),
            icon: const Icon(
              Icons.create_new_folder_outlined,
              color: _primaryColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildSearchField(),
          _buildCategoryFilters(),
          Expanded(child: _buildContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _openNoteEditor(),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Note'),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keep your thoughts organized.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatCard(
                icon: Icons.folder_open_rounded,
                label: 'Folders here',
                count: _visibleFolders.length,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.sticky_note_2_outlined,
                label: 'Notes here',
                count: _visibleNotes.length,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int count,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primaryColor, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  Widget _buildSearchField() {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colors.onSurface),
        onChanged: (value) {
          setState(() => _searchQuery = value.trim());
        },
        decoration: InputDecoration(
          hintText: 'Search notes...',
          hintStyle: TextStyle(color: colors.onSurfaceVariant),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colors.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            icon: Icon(
              Icons.close_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _primaryColor,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CATEGORY FILTERS
  // ------------------------------------------------------------

  Widget _buildCategoryFilters() {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _selectedCategory = category);
            },
            selectedColor: _primaryColor,
            backgroundColor: colors.surfaceContainerHighest,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : colors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            side: BorderSide(
              color: isSelected ? _primaryColor : colors.outlineVariant,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTENT
  // ------------------------------------------------------------

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final folders = _visibleFolders;
    final notes = _visibleNotes;

    if (folders.isEmpty && notes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        if (folders.isNotEmpty) ...[
          _buildSectionTitle('Folders', folders.length),
          const SizedBox(height: 10),
          ...folders.map(_buildFolderTile),
          const SizedBox(height: 22),
        ],
        if (notes.isNotEmpty) ...[
          _buildSectionTitle('Notes', notes.length),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notes.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 218,
            ),
            itemBuilder: (context, index) {
              return _buildNoteCard(notes[index]);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // FOLDER TILE
  // ------------------------------------------------------------

  Widget _buildFolderTile(NoteFolder folder) {
    final colors = Theme.of(context).colorScheme;

    final childCount =
        _folders.where((item) => item.parentId == folder.id).length;

    final noteCount = _noteCountForFolder(folder.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ListTile(
        onTap: () => _openFolder(folder),
        leading: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0CF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.folder_rounded,
            color: Color(0xFFD99A22),
          ),
        ),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        subtitle: Text(
          '$childCount subfolders · $noteCount notes',
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
        trailing: PopupMenuButton<String>(
          iconColor: colors.onSurfaceVariant,
          onSelected: (action) {
            if (action == 'rename') {
              _showFolderDialog(folder: folder);
            } else if (action == 'delete') {
              _confirmDeleteFolder(folder);
            } else if (action == 'subfolder') {
              _openFolder(folder);
              _showFolderDialog();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'subfolder',
              child: Text('Add subfolder'),
            ),
            PopupMenuItem(
              value: 'rename',
              child: Text('Rename'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // NOTE CARD
  // ------------------------------------------------------------

  Widget _buildNoteCard(NoteItem note) {
    final colors = Theme.of(context).colorScheme;
    final accentColor = _categoryColor(note.category);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openNoteEditor(note: note),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                  iconColor: colors.onSurfaceVariant,
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openNoteEditor(note: note);
                    } else if (action == 'delete') {
                      _confirmDeleteNote(note);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content.isEmpty ? 'No additional text' : note.content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            if (note.pdfName != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: note.pdfPath != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(
                              filePath: note.pdfPath!,
                              title: note.pdfName,
                            ),
                          ),
                        );
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          note.pdfName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _formatDate(note.updatedAt),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    final hasSearch = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.note_add_outlined,
              size: 58,
              color: _primaryColor.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No results found' : 'Nothing here yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try a different search or category.'
                  : 'Create a folder or add your first note.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _showFolderDialog(),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Create folder'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CATEGORY AND DATE HELPERS
  // ------------------------------------------------------------

  Color _categoryColor(String category) {
    switch (category) {
      case 'Personal':
        return const Color(0xFFDA7B35);
      case 'Study':
        return const Color(0xFF3285D5);
      case 'Work':
        return const Color(0xFF299C79);
      default:
        return _primaryColor;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}

// ============================================================
// NOTE EDITOR SHEET
// ============================================================

class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({
    super.key,
    required this.categories,
    this.initialNote,
  });

  final List<String> categories;
  final NoteItem? initialNote;

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  static const Color _primaryColor = Color(0xFF5146E5);

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  String? _selectedCategory;
  String? _pdfName;
  String? _pdfPath;

  bool _isPickingPdf = false;

  @override
  void initState() {
    super.initState();

    final note = widget.initialNote;

    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');

    if (note != null && widget.categories.contains(note.category)) {
      _selectedCategory = note.category;
    } else if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories.first;
    }

    _pdfName = note?.pdfName;
    _pdfPath = note?.pdfPath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

 // pickup
  Future<void> _pickPdf() async {
    if (_isPickingPdf) return;

    setState(() => _isPickingPdf = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (!mounted || result.isEmpty) return;

      final file = result.first;

      if (file.path == null) {
        throw Exception('Selected PDF file path is unavailable.');
      }

      final saved = await NotesSyncController.instance.runOperation(() async {
        final appDirectory = await getApplicationDocumentsDirectory();

        final pdfDirectory = Directory(
          p.join(appDirectory.path, 'trackflow_pdfs'),
        );

        if (!await pdfDirectory.exists()) {
          await pdfDirectory.create(recursive: true);
        }

        final safeName = p.basename(file.name);

        final destinationPath = p.join(
          pdfDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}_$safeName',
        );

        await File(file.path!).copy(destinationPath);

        if (mounted) {
          setState(() {
            _pdfName = file.name;
            _pdfPath = destinationPath;
          });
        }
      });

      if (!saved || !mounted) return;
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingPdf = false);
      }
    }
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note title.')),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a category before saving.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      NoteDraft(
        title: title,
        content: content,
        category: _selectedCategory!,
        pdfName: _pdfName,
        pdfPath: _pdfPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEditing = widget.initialNote != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              isEditing ? 'Edit note' : 'Create note',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: colors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter note title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              minLines: 5,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: colors.onSurface),
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Write your notes here...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.onSurface),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              hint: const Text('Select category'),
              items: widget.categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: widget.categories.isEmpty
                  ? null
                  : (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            if (widget.categories.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'No categories available. Add a category first.',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isPickingPdf ? null : _pickPdf,
              icon: _isPickingPdf
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.attach_file_rounded),
              label: Text(
                _isPickingPdf
                    ? 'Saving PDF...'
                    : _pdfName == null
                    ? 'Attach PDF'
                    : 'Change PDF',
              ),
            ),
            if (_pdfName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pdfName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurface),
                      ),
                    ),
                    if (_pdfPath != null)
                      IconButton(
                        tooltip: 'View PDF',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfViewerScreen(
                                filePath: _pdfPath!,
                                title: _pdfName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 20,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Remove attachment',
                      onPressed: () {
                        setState(() {
                          _pdfName = null;
                          _pdfPath = null;
                        });
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isPickingPdf ? null : _saveNote,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  isEditing ? 'Save changes' : 'Create note',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FOLDER NAME DIALOG
// ============================================================

class _FolderNameDialog extends StatefulWidget {
  final String initialName;
  final bool isRename;

  const _FolderNameDialog({
    required this.initialName,
    required this.isRename,
  });

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        widget.isRename ? 'Rename Folder' : 'Create Folder',
        style: TextStyle(color: colors.onSurface),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(color: colors.onSurface),
        decoration: const InputDecoration(hintText: 'Enter folder name'),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();

            if (name.isNotEmpty) {
              Navigator.pop(context, name);
            }
          },
          child: Text(widget.isRename ? 'Rename' : 'Create'),
        ),
      ],
    );
  }
}
