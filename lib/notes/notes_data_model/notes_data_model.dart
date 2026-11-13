
class NoteFolder {
  NoteFolder({
    required this.id,
    required this.name,
    required this.parentId,
  });

  final String id;
  String name;
  final String? parentId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
    };
  }

  factory NoteFolder.fromMap(Map<String, dynamic> map) {
    return NoteFolder(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      parentId: map['parentId']?.toString(),
    );
  }
}

class NoteItem {
  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.folderId,
    required this.pdfName,
    this.pdfPath,
    required this.updatedAt,
  });

  final String id;
  String title;
  String content;
  String category;
  final String? folderId;
  String? pdfName;
  String? pdfPath;
  DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'folderId': folderId,
      'pdfName': pdfName,
      'pdfPath': pdfPath,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory NoteItem.fromMap(Map<String, dynamic> map) {
    final rawUpdatedAt = map['updatedAt'];

    DateTime parsedUpdatedAt;

    if (rawUpdatedAt is DateTime) {
      parsedUpdatedAt = rawUpdatedAt;
    } else if (rawUpdatedAt is String) {
      parsedUpdatedAt =
          DateTime.tryParse(rawUpdatedAt) ?? DateTime.now();
    } else if (rawUpdatedAt != null &&
        rawUpdatedAt.runtimeType.toString() == 'Timestamp') {
      parsedUpdatedAt = rawUpdatedAt.toDate();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    return NoteItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      folderId: map['folderId']?.toString(),
      pdfName: map['pdfName']?.toString(),
      pdfPath: map['pdfPath']?.toString(),
      updatedAt: parsedUpdatedAt,
    );
  }
}

class NoteDraft {
  const NoteDraft({
    required this.title,
    required this.content,
    required this.category,
    required this.pdfName,
    this.pdfPath,
  });

  final String title;
  final String content;
  final String category;
  final String? pdfName;
  final String? pdfPath;
}
