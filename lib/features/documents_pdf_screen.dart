import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../Statemanage_riverpod/provider/task_provider.dart';
import '../notes/note_database/database.dart';
import 'Ai _Assistant_screen.dart';
import 'pdf_viewer_screen.dart';

class PdfDocumentItem {
  final String id;
  final String name;
  final String path;
  final String source; // 'task', 'note', 'imported'
  final String? sourceTitle;
  final int sizeBytes;
  final DateTime modifiedAt;

  PdfDocumentItem({
    required this.id,
    required this.name,
    required this.path,
    required this.source,
    this.sourceTitle,
    required this.sizeBytes,
    required this.modifiedAt,
  });
}

class DocumentsPdfScreen extends ConsumerStatefulWidget {
  const DocumentsPdfScreen({super.key});

  @override
  ConsumerState<DocumentsPdfScreen> createState() => _DocumentsPdfScreenState();
}

class _DocumentsPdfScreenState extends ConsumerState<DocumentsPdfScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'Tasks', 'Notes', 'Imported'
  String _searchQuery = '';
  bool _isLoading = true;
  List<PdfDocumentItem> _documents = [];

  static const Color primaryColor = Color(0xFF5146E5);

  @override
  void initState() {
    super.initState();
    _loadAllPdfs();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPdfs() async {
    setState(() => _isLoading = true);
    final items = <PdfDocumentItem>[];
    final seenPaths = <String>{};

    try {
      // 1. Gather from Tasks
      final tasks = ref.read(taskProvider);
      for (final task in tasks) {
        final path = task.pdfPath;
        if (path != null && path.isNotEmpty && !seenPaths.contains(path)) {
          final file = File(path);
          if (await file.exists()) {
            final stat = await file.stat();
            seenPaths.add(path);
            items.add(
              PdfDocumentItem(
                id: 'task_${task.id}',
                name: task.pdfName ?? p.basename(path),
                path: path,
                source: 'task',
                sourceTitle: task.title,
                sizeBytes: stat.size,
                modifiedAt: stat.modified,
              ),
            );
          }
        }
      }

      // 2. Gather from Notes
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final notes = await NotesDatabase.instance.getNotes(userId: uid);
          for (final note in notes) {
            final path = note.pdfPath;
            if (path != null && path.isNotEmpty && !seenPaths.contains(path)) {
              final file = File(path);
              if (await file.exists()) {
                final stat = await file.stat();
                seenPaths.add(path);
                items.add(
                  PdfDocumentItem(
                    id: 'note_${note.id}',
                    name: note.pdfName ?? p.basename(path),
                    path: path,
                    source: 'note',
                    sourceTitle: note.title,
                    sizeBytes: stat.size,
                    modifiedAt: stat.modified,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching notes for PDF list: $e');
        }
      }

      // 3. Gather from general trackflow_pdfs directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final pdfDir = Directory(p.join(appDir.path, 'trackflow_pdfs'));
        if (await pdfDir.exists()) {
          final files = pdfDir.listSync().whereType<File>();
          for (final file in files) {
            if (file.path.toLowerCase().endsWith('.pdf') && !seenPaths.contains(file.path)) {
              final stat = await file.stat();
              seenPaths.add(file.path);
              items.add(
                PdfDocumentItem(
                  id: 'imported_${p.basename(file.path)}',
                  name: p.basename(file.path),
                  path: file.path,
                  source: 'imported',
                  sourceTitle: 'Saved in Documents',
                  sizeBytes: stat.size,
                  modifiedAt: stat.modified,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching trackflow_pdfs folder: $e');
      }

      // Sort newest first
      items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    } catch (e) {
      debugPrint('Error loading PDFs: $e');
    } finally {
      if (mounted) {
        setState(() {
          _documents = items;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importNewPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty) return;

      final pickedFile = result.first;
      if (pickedFile.path == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory(p.join(appDir.path, 'trackflow_pdfs'));
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      final cleanName = pickedFile.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final destPath = p.join(
        pdfDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_$cleanName',
      );

      await File(pickedFile.path!).copy(destPath);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF imported successfully!')),
      );

      await _loadAllPdfs();

      // Open immediately in viewer
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: destPath,
            title: pickedFile.name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import PDF: $e')),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  List<PdfDocumentItem> get _filteredDocuments {
    return _documents.where((item) {
      final matchesFilter = _selectedFilter == 'All' ||
          (_selectedFilter == 'Tasks' && item.source == 'task') ||
          (_selectedFilter == 'Notes' && item.source == 'note') ||
          (_selectedFilter == 'Imported' && item.source == 'imported');

      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery) ||
          (item.sourceTitle?.toLowerCase().contains(_searchQuery) ?? false);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final docs = _filteredDocuments;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text(
          'Documents & PDFs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllPdfs,
          ),
          IconButton(
            tooltip: 'Import PDF',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _importNewPdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importNewPdf,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Import PDF'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _filterChip('All', _documents.length),
                  const SizedBox(width: 8),
                  _filterChip('Tasks', _documents.where((d) => d.source == 'task').length),
                  const SizedBox(width: 8),
                  _filterChip('Notes', _documents.where((d) => d.source == 'note').length),
                  const SizedBox(width: 8),
                  _filterChip('Imported', _documents.where((d) => d.source == 'imported').length),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Document List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : docs.isEmpty
                      ? _buildEmptyState(colors)
                      : RefreshIndicator(
                          onRefresh: _loadAllPdfs,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: docs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = docs[index];
                              return _buildDocumentCard(item, colors);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    final colors = Theme.of(context).colorScheme;

    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : colors.onSurface,
      ),
      selectedColor: primaryColor,
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      checkmarkColor: Colors.white,
      shape: RoundedRectangle64Border(),
      onSelected: (val) {
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }

  Widget _buildDocumentCard(PdfDocumentItem item, ColorScheme colors) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;

    switch (item.source) {
      case 'task':
        badgeColor = const Color(0xFF10B981);
        badgeIcon = Icons.task_alt_rounded;
        badgeLabel = 'Task: ${item.sourceTitle ?? ""}';
        break;
      case 'note':
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = Icons.sticky_note_2_rounded;
        badgeLabel = 'Note: ${item.sourceTitle ?? ""}';
        break;
      default:
        badgeColor = const Color(0xFF6366F1);
        badgeIcon = Icons.folder_open_rounded;
        badgeLabel = 'Imported File';
    }

    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                filePath: item.path,
                title: item.name,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.red,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _formatFileSize(item.sizeBytes),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              ' • ${_formatDate(item.modifiedAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Source Badge
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 13, color: badgeColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              badgeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions: View & Ask Gemini
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiAssistantScreen(
                                initialPdfPath: item.path,
                                initialPdfName: item.name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: primaryColor,
                        ),
                        label: const Text(
                          'Ask AI',
                          style: TextStyle(fontSize: 11, color: primaryColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfViewerScreen(
                                filePath: item.path,
                                title: item.name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('View', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                size: 40,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No documents match "$_searchQuery"'
                  : 'No PDF documents found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with different keywords.'
                  : 'Attach PDFs to tasks, notes, or import any PDF to view and analyze with Gemini AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _importNewPdf,
              style: FilledButton.styleFrom(backgroundColor: primaryColor),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Import PDF'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class RoundedRectangle64Border extends RoundedRectangleBorder {
  RoundedRectangle64Border() : super(borderRadius: BorderRadius.circular(20));
}
