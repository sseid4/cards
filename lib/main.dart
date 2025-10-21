import 'package:flutter/material.dart';
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              Text(
                folder.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${folder.cardCount} cards',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
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
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    final result = await showDialog<_CardEditResult>(
      context: context,
      builder: (context) => _CardEditDialog(
        title: 'Add Card',
        initialRank: 1,
        initialName: _cardName(widget.folderName, 1),
      ),
    );
    if (result != null) {
      await DatabaseHelper.instance.insertCard(
        folderId: widget.folderId,
        suit: widget.folderName,
        rank: result.rank,
        name: result.name.isEmpty ? null : result.name,
      );
      _reload();
    }
  }

  Future<void> _onEditCard(Map<String, dynamic> c) async {
    final currentRank = (c['rank'] as num).toInt();
    final currentName = c['name'] as String? ?? '';
    final result = await showDialog<_CardEditResult>(
      context: context,
      builder: (context) => _CardEditDialog(
        title: 'Edit Card',
        initialRank: currentRank,
        initialName: currentName,
      ),
    );
    if (result != null) {
      final newUrl = _assetPathForCard(widget.folderName, result.rank);
      await DatabaseHelper.instance.updateCard(
        id: (c['id'] as num).toInt(),
        name: result.name,
        rank: result.rank,
        imageUrl: newUrl,
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
  _CardEditResult(this.rank, this.name);
}

class _CardEditDialog extends StatefulWidget {
  final String title;
  final int initialRank;
  final String initialName;
  const _CardEditDialog({
    required this.title,
    required this.initialRank,
    required this.initialName,
  });

  @override
  State<_CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<_CardEditDialog> {
  late int _rank;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _rank = widget.initialRank;
    _nameCtrl = TextEditingController(text: widget.initialName);
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
          onPressed: () => Navigator.pop(
            context,
            _CardEditResult(_rank, _nameCtrl.text.trim()),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
