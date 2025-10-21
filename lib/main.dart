import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;
import 'db/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cards App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const FoldersScreen(),
    );
  }
}

class FolderSummary {
  final int id;
  final String name;
  final int cardCount;
  final String? previewUrl;

  const FolderSummary({
    required this.id,
    required this.name,
    required this.cardCount,
    required this.previewUrl,
  });

  factory FolderSummary.fromMap(Map<String, Object?> m) {
    return FolderSummary(
      id: (m['id'] as num).toInt(),
      name: (m['name'] as String),
      cardCount: (m['card_count'] as num).toInt(),
      previewUrl: m['preview_url'] as String?,
    );
  }
}

// Screen 1: Folders Screen
class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  late Future<List<FolderSummary>> _foldersFuture;

  @override
  void initState() {
    super.initState();
    _foldersFuture = _loadFolders();
  }

  Future<List<FolderSummary>> _loadFolders() async {
    final rows = await DatabaseHelper.instance.fetchFolderSummaries();
    return rows.map(FolderSummary.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: FutureBuilder<List<FolderSummary>>(
        future: _foldersFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data ?? const [];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final folder = data[index];
                return _buildFolderCard(context, folder);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddFolder,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, FolderSummary folder) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CardsScreen(folderId: folder.id, folderName: folder.name),
            ),
          );
          setState(() {
            _foldersFuture = _loadFolders();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') {
                        _onRenameFolder(folder);
                      } else if (v == 'delete') {
                        _onDeleteFolder(folder);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: folder.previewUrl != null
                        ? Image.asset(
                            folder.previewUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 36,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.style,
                              size: 36,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${folder.cardCount} cards',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAddFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      try {
        await DatabaseHelper.instance.insertFolder(name);
        if (!mounted) return;
        setState(() {
          _foldersFuture = _loadFolders();
        });
      } on DatabaseException catch (e) {
        if (!mounted) return;
        final isUniqueViolation =
            e.isUniqueConstraintError() ||
            e.toString().toLowerCase().contains('unique');
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot create folder'),
            content: Text(
              isUniqueViolation
                  ? 'A folder with that name already exists.'
                  : 'Failed to create folder. ${e.toString()}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create folder. $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _onRenameFolder(FolderSummary folder) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController(text: folder.name);
        return AlertDialog(
          title: const Text('Rename Folder'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Folder name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty && name != folder.name) {
      await DatabaseHelper.instance.updateFolderName(folder.id, name);
      if (!mounted) return;
      setState(() {
        _foldersFuture = _loadFolders();
      });
    }
  }

  Future<void> _onDeleteFolder(FolderSummary folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Delete "${folder.name}" and all its cards?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteFolder(folder.id);
      if (!mounted) return;
      setState(() {
        _foldersFuture = _loadFolders();
      });
    }
  }
}

// Screen 2: Cards Grid with add/update/delete
class CardsScreen extends StatefulWidget {
  final int folderId;
  final String folderName;

  const CardsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  late Future<List<Map<String, dynamic>>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _cardsFuture = DatabaseHelper.instance.fetchCardsByFolder(widget.folderId);
  }

  void _reload() {
    setState(() {
      _cardsFuture = DatabaseHelper.instance.fetchCardsByFolder(
        widget.folderId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cardsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final cards = snap.data ?? const [];
          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No cards yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'You need at least 3 cards in this folder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // If fewer than 3 cards, show a warning banner above the grid
          final needsMinWarning = cards.length < 3;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (needsMinWarning)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'You need at least 3 cards in this folder.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 3 / 4,
                        ),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final c = cards[index];
                      return _buildCardTile(c);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddCard,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCardTile(Map<String, dynamic> c) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: c['image_url'] != null
                ? Image.asset(
                    c['image_url'] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 36,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Container(color: Colors.grey.shade200),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (c['name'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (v) {
                        if (v == 'edit') {
                          _onEditCard(c);
                        } else if (v == 'delete') {
                          _onDeleteCard(c);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddCard() async {
    final folders = await DatabaseHelper.instance.fetchFoldersSimple();
    if (!context.mounted) return;
    final result = await showDialog<_CardEditResult>(
      context: context,
      builder: (context) => _CardEditDialog(
        title: 'Add Card',
        initialRank: 1,
        initialName: _cardName(widget.folderName, 1),
        folders: folders,
        initialFolderId: widget.folderId,
      ),
    );
    if (result != null) {
      // Enforce max 6 cards per folder
      final count = await DatabaseHelper.instance.countCardsInFolder(
        result.folderId,
      );
      if (count >= 6) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Limit reached'),
            content: Text('This folder can only hold 6 cards.'),
          ),
        );
        return;
      }
      await DatabaseHelper.instance.insertCard(
        folderId: result.folderId,
        suit: result.folderName,
        rank: result.rank,
        name: result.name.isEmpty ? null : result.name,
      );
      _reload();
    }
  }

  Future<void> _onEditCard(Map<String, dynamic> c) async {
    final currentRank = (c['rank'] as num).toInt();
    final currentName = c['name'] as String? ?? '';
    final folders = await DatabaseHelper.instance.fetchFoldersSimple();
    if (!context.mounted) return;
    final currentFolderId = (c['folder_id'] as num).toInt();
    final result = await showDialog<_CardEditResult>(
      context: context,
      builder: (context) => _CardEditDialog(
        title: 'Edit Card',
        initialRank: currentRank,
        initialName: currentName,
        folders: folders,
        initialFolderId: currentFolderId,
      ),
    );
    if (result != null) {
      // If moving to a new folder, enforce max 6 there
      if (result.folderId != currentFolderId) {
        final targetCount = await DatabaseHelper.instance.countCardsInFolder(
          result.folderId,
        );
        if (targetCount >= 6) {
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('Limit reached'),
              content: Text('This folder can only hold 6 cards.'),
            ),
          );
          return;
        }
      }
      final newUrl = _assetPathForCard(result.folderName, result.rank);
      await DatabaseHelper.instance.updateCard(
        id: (c['id'] as num).toInt(),
        name: result.name,
        rank: result.rank,
        imageUrl: newUrl,
        folderId: result.folderId,
        suit: result.folderName,
      );
      _reload();
    }
  }

  Future<void> _onDeleteCard(Map<String, dynamic> c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text('Are you sure you want to delete this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteCard((c['id'] as num).toInt());
      _reload();
    }
  }

  String _cardName(String suit, int rank) {
    switch (rank) {
      case 1:
        return 'Ace of $suit';
      case 11:
        return 'Jack of $suit';
      case 12:
        return 'Queen of $suit';
      case 13:
        return 'King of $suit';
      default:
        return '$rank of $suit';
    }
  }

  String _assetPathForCard(String suit, int rank) {
    return 'assets/images/cards/${suit.toLowerCase()}/$rank.png';
  }
}

class _CardEditResult {
  final int rank;
  final String name;
  final int folderId;
  final String folderName;
  _CardEditResult(this.rank, this.name, this.folderId, this.folderName);
}

class _CardEditDialog extends StatefulWidget {
  final String title;
  final int initialRank;
  final String initialName;
  final List<Map<String, dynamic>> folders; // [{id,name}]
  final int initialFolderId;
  const _CardEditDialog({
    required this.title,
    required this.initialRank,
    required this.initialName,
    required this.folders,
    required this.initialFolderId,
  });

  @override
  State<_CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<_CardEditDialog> {
  late int _rank;
  late TextEditingController _nameCtrl;
  late int _folderId;

  @override
  void initState() {
    super.initState();
    _rank = widget.initialRank;
    _nameCtrl = TextEditingController(text: widget.initialName);
    _folderId = widget.initialFolderId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Folder:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _folderId,
                items: [
                  for (final f in widget.folders)
                    DropdownMenuItem(
                      value: (f['id'] as num).toInt(),
                      child: Text(f['name'] as String),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _folderId = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Rank:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _rank,
                items: [
                  for (int r = 1; r <= 13; r++)
                    DropdownMenuItem(value: r, child: Text('$r')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _rank = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final selected = widget.folders.firstWhere(
              (f) => (f['id'] as num).toInt() == _folderId,
            );
            final folderName = selected['name'] as String;
            Navigator.pop(
              context,
              _CardEditResult(
                _rank,
                _nameCtrl.text.trim(),
                _folderId,
                folderName,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
