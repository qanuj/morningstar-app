import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bottom sheet emoji picker with search, categories, and recents.
class EmojiPickerSheet extends StatefulWidget {
  const EmojiPickerSheet({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  static const _recentEmojisPreferenceKey = 'emoji_picker_recent_emojis';
  static const _maxRecentEmojis = 9;
  static const _recentGroupId = 'recent';
  static const _recentGroupTitle = 'Frequently Used';
  static const _recentGroupIcon = '🕒';

  // Default set of popular emojis for frequently used
  static const _defaultFrequentlyUsed = [
    '😀', '😂', '😍', '😊', '👍', '❤️',
    '😢', '😎', '🤔'
  ];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Map<String, GlobalKey> _groupKeys;
  late final List<_EmojiEntry> _allEmojis;
  late final List<_CategoryDescriptor> _categoryDescriptors;

  List<String> _recentEmojis = const [];
  String _searchQuery = '';
  bool _recentsLoaded = false;

  @override
  void initState() {
    super.initState();
    _groupKeys = {
      _recentGroupId: GlobalKey(),
      for (final group in _emojiGroups) group.id: GlobalKey(),
    };
    _allEmojis = [
      for (final group in _emojiGroups)
        for (final emoji in group.emojis)
          _EmojiEntry(
            character: emoji.character,
            keywords: emoji.keywords,
            groupId: group.id,
          ),
    ];
    _categoryDescriptors = [
      const _CategoryDescriptor(id: _recentGroupId, icon: _recentGroupIcon),
      ..._emojiGroups
          .map((group) => _CategoryDescriptor(id: group.id, icon: group.icon))
          .toList(),
    ];
    _searchController.addListener(_handleSearchChanged);
    _loadRecentEmojis();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentEmojisPreferenceKey);
    if (!mounted) {
      return;
    }
    setState(() {
      // Use default frequently used emojis if no stored recents exist
      _recentEmojis = stored ?? _defaultFrequentlyUsed;
      _recentsLoaded = true;
    });
  }

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _handleEmojiTap(String emoji) {
    widget.onSelected(emoji);
    _updateRecentEmojis(emoji);
  }

  Future<void> _updateRecentEmojis(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = [..._recentEmojis];
    existing.remove(emoji);
    existing.insert(0, emoji);
    if (existing.length > _maxRecentEmojis) {
      existing.removeRange(_maxRecentEmojis, existing.length);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _recentEmojis = existing;
    });
    await prefs.setStringList(_recentEmojisPreferenceKey, existing);
  }

  void _jumpToGroup(String groupId) {
    FocusScope.of(context).unfocus();
    final targetContext = _groupKeys[groupId]?.currentContext;
    if (targetContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  List<_EmojiEntry> _searchEmojis(String query) {
    if (query.isEmpty) {
      return const [];
    }
    return _allEmojis.where((entry) {
      return entry.character.contains(query) ||
          entry.keywords.any((keyword) => keyword.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchResults = _searchEmojis(_searchQuery);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _searchQuery.isNotEmpty
                    ? _EmojiSearchResults(
                        key: const ValueKey('search'),
                        emojis: searchResults,
                        query: _searchQuery,
                        onTap: _handleEmojiTap,
                      )
                    : _EmojiSectionList(
                        key: const ValueKey('sections'),
                        scrollController: _scrollController,
                        recentEmojis: _recentsLoaded ? _recentEmojis : const [],
                        recentGroupKey: _groupKeys[_recentGroupId]!,
                        groupKeys: _groupKeys,
                        onEmojiTap: _handleEmojiTap,
                      ),
              ),
            ),
            _EmojiCategoryBar(
              categories: _categoryDescriptors,
              onCategoryTap: _jumpToGroup,
              isSearchActive: _searchQuery.isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiSectionList extends StatelessWidget {
  const _EmojiSectionList({
    super.key,
    required this.scrollController,
    required this.recentEmojis,
    required this.recentGroupKey,
    required this.groupKeys,
    required this.onEmojiTap,
  });

  final ScrollController scrollController;
  final List<String> recentEmojis;
  final GlobalKey recentGroupKey;
  final Map<String, GlobalKey> groupKeys;
  final ValueChanged<String> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (recentEmojis.isNotEmpty)
          _EmojiSection(
            key: recentGroupKey,
            title: _EmojiPickerSheetState._recentGroupTitle,
            emojis: [
              for (final emoji in recentEmojis)
                _EmojiDefinition(character: emoji, keywords: const []),
            ],
            onEmojiTap: onEmojiTap,
            titleStyle: theme.textTheme.labelLarge,
            padding: const EdgeInsets.only(top: 8, bottom: 16),
          ),
        for (final group in _emojiGroups)
          _EmojiSection(
            key: groupKeys[group.id],
            title: group.title,
            emojis: group.emojis,
            onEmojiTap: onEmojiTap,
            titleStyle: theme.textTheme.labelLarge,
            padding: const EdgeInsets.only(top: 8, bottom: 16),
          ),
      ],
    );
  }
}

class _EmojiSection extends StatelessWidget {
  const _EmojiSection({
    super.key,
    required this.title,
    required this.emojis,
    required this.onEmojiTap,
    required this.titleStyle,
    required this.padding,
  });

  final String title;
  final List<_EmojiDefinition> emojis;
  final ValueChanged<String> onEmojiTap;
  final TextStyle? titleStyle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(title, style: titleStyle),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const emojisPerRow = 9;
              final rows = <Widget>[];
              // Use taller height on Android, original height on iOS
              final height = Theme.of(context).platform == TargetPlatform.android ? 40.0 : 32.0;

              for (int i = 0; i < emojis.length; i += emojisPerRow) {
                final rowEmojis = emojis.skip(i).take(emojisPerRow).toList();
                rows.add(
                  Padding(
                    padding: EdgeInsets.only(bottom: i + emojisPerRow < emojis.length ? 8.0 : 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int j = 0; j < emojisPerRow; j++)
                          if (j < rowEmojis.length)
                            _EmojiButton(emoji: rowEmojis[j].character, onTap: onEmojiTap)
                          else
                            SizedBox(width: 32, height: height), // Empty space for alignment
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmojiCategoryBar extends StatelessWidget {
  const _EmojiCategoryBar({
    required this.categories,
    required this.onCategoryTap,
    required this.isSearchActive,
  });

  final List<_CategoryDescriptor> categories;
  final ValueChanged<String> onCategoryTap;
  final bool isSearchActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: categories
            .map(
              (category) => _CategoryIconButton(
                emoji: category.icon,
                isDisabled: isSearchActive,
                onTap: () => onCategoryTap(category.id),
              ),
            )
            .toList(),
      ),
    );
  }
}

class EmojiPickerSheetContainer extends StatelessWidget {
  const EmojiPickerSheetContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _CategoryIconButton extends StatelessWidget {
  const _CategoryIconButton({
    required this.emoji,
    required this.onTap,
    this.isDisabled = false,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: isDisabled ? 0.4 : 1,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(emoji, style: theme.textTheme.titleMedium),
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.onTap});

  final String emoji;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    // Use taller height on Android, original height on iOS
    final height = Theme.of(context).platform == TargetPlatform.android ? 40.0 : 32.0;

    return GestureDetector(
      onTap: () => onTap(emoji),
      child: Container(
        width: 32,
        height: height,
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

class _EmojiSearchResults extends StatelessWidget {
  const _EmojiSearchResults({
    super.key,
    required this.emojis,
    required this.query,
    required this.onTap,
  });

  final List<_EmojiEntry> emojis;
  final String query;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (emojis.isEmpty) {
      return Center(child: Text('No emojis match "$query"'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return _EmojiButton(emoji: emoji.character, onTap: onTap);
      },
    );
  }
}

class _EmojiEntry {
  const _EmojiEntry({
    required this.character,
    required this.keywords,
    required this.groupId,
  });

  final String character;
  final List<String> keywords;
  final String groupId;
}

class _EmojiGroup {
  const _EmojiGroup({
    required this.id,
    required this.title,
    required this.icon,
    required this.emojis,
  });

  final String id;
  final String title;
  final String icon;
  final List<_EmojiDefinition> emojis;
}

class _EmojiDefinition {
  const _EmojiDefinition({required this.character, required this.keywords});

  final String character;
  final List<String> keywords;
}

class _CategoryDescriptor {
  const _CategoryDescriptor({required this.id, required this.icon});

  final String id;
  final String icon;
}

const List<_EmojiGroup> _emojiGroups = [
  _EmojiGroup(
    id: 'smileys',
    title: 'Smileys & People',
    icon: '😊',
    emojis: [
      _EmojiDefinition(
        character: '😀',
        keywords: ['grinning face', 'smile', 'happy'],
      ),
      _EmojiDefinition(
        character: '😃',
        keywords: ['grinning big eyes', 'smile', 'happy'],
      ),
      _EmojiDefinition(
        character: '😄',
        keywords: ['grinning smiling eyes', 'smile', 'joy'],
      ),
      _EmojiDefinition(
        character: '😁',
        keywords: ['beaming face', 'smile', 'teeth'],
      ),
      _EmojiDefinition(
        character: '😆',
        keywords: ['grinning squinting', 'laugh', 'happy'],
      ),
      _EmojiDefinition(
        character: '😅',
        keywords: ['grinning sweat', 'relief', 'nervous'],
      ),
      _EmojiDefinition(
        character: '😂',
        keywords: ['tears of joy', 'lol', 'laugh'],
      ),
      _EmojiDefinition(
        character: '🤣',
        keywords: ['rolling on the floor', 'rofl', 'laugh'],
      ),
      _EmojiDefinition(
        character: '😊',
        keywords: ['smiling eyes', 'blush', 'happy'],
      ),
      _EmojiDefinition(
        character: '😇',
        keywords: ['smiling halo', 'angel', 'innocent'],
      ),
      _EmojiDefinition(
        character: '🙂',
        keywords: ['slightly smiling', 'calm', 'content'],
      ),
      _EmojiDefinition(
        character: '🙃',
        keywords: ['upside-down', 'silly', 'playful'],
      ),
      _EmojiDefinition(
        character: '😉',
        keywords: ['winking face', 'wink', 'playful'],
      ),
      _EmojiDefinition(
        character: '😍',
        keywords: ['heart eyes', 'love', 'adore'],
      ),
      _EmojiDefinition(
        character: '😘',
        keywords: ['blowing kiss', 'love', 'affection'],
      ),
      _EmojiDefinition(
        character: '😗',
        keywords: ['kissing face', 'affection', 'kiss'],
      ),
      _EmojiDefinition(
        character: '😙',
        keywords: ['kissing eyes', 'smile', 'affection'],
      ),
      _EmojiDefinition(
        character: '😚',
        keywords: ['kissing closed eyes', 'affection', 'love'],
      ),
      _EmojiDefinition(
        character: '🥰',
        keywords: ['smiling hearts', 'love', 'in love'],
      ),
      _EmojiDefinition(
        character: '🤗',
        keywords: ['hugging face', 'hug', 'warm'],
      ),
      _EmojiDefinition(
        character: '🤔',
        keywords: ['thinking face', 'hmm', 'idea'],
      ),
      _EmojiDefinition(
        character: '🤨',
        keywords: ['raised eyebrow', 'skeptical', 'dubious'],
      ),
      _EmojiDefinition(
        character: '😐',
        keywords: ['neutral face', 'meh', 'flat'],
      ),
      _EmojiDefinition(
        character: '😑',
        keywords: ['expressionless', 'blank', 'meh'],
      ),
      _EmojiDefinition(
        character: '😶',
        keywords: ['without mouth', 'speechless', 'mute'],
      ),
      _EmojiDefinition(
        character: '🙄',
        keywords: ['rolling eyes', 'eyeroll', 'annoyed'],
      ),
      _EmojiDefinition(
        character: '😏',
        keywords: ['smirking face', 'smug', 'sly'],
      ),
      _EmojiDefinition(
        character: '😴',
        keywords: ['sleeping face', 'zzz', 'tired'],
      ),
      _EmojiDefinition(
        character: '😪',
        keywords: ['sleepy face', 'drool', 'tired'],
      ),
      _EmojiDefinition(
        character: '😭',
        keywords: ['loudly crying', 'sob', 'sad'],
      ),
      _EmojiDefinition(
        character: '😢',
        keywords: ['crying face', 'sad', 'tear'],
      ),
      _EmojiDefinition(
        character: '😤',
        keywords: ['steam nose', 'triumph', 'proud'],
      ),
      _EmojiDefinition(
        character: '😡',
        keywords: ['pouting face', 'angry', 'mad'],
      ),
      _EmojiDefinition(
        character: '😳',
        keywords: ['flushed face', 'blush', 'shocked'],
      ),
      _EmojiDefinition(
        character: '🥺',
        keywords: ['pleading face', 'beg', 'puppy eyes'],
      ),
      _EmojiDefinition(
        character: '🤤',
        keywords: ['drooling face', 'yum', 'hungry'],
      ),
      _EmojiDefinition(
        character: '🤯',
        keywords: ['exploding head', 'mind blown', 'shock'],
      ),
      _EmojiDefinition(
        character: '🤠',
        keywords: ['cowboy hat', 'yee haw', 'cowboy'],
      ),
      _EmojiDefinition(
        character: '🤡',
        keywords: ['clown face', 'circus', 'jester'],
      ),
      _EmojiDefinition(
        character: '🤫',
        keywords: ['shushing face', 'quiet', 'secret'],
      ),
    ],
  ),
  _EmojiGroup(
    id: 'animals',
    title: 'Animals & Nature',
    icon: '🐻',
    emojis: [
      _EmojiDefinition(character: '🐶', keywords: ['dog face', 'pet', 'dog']),
      _EmojiDefinition(character: '🐱', keywords: ['cat face', 'pet', 'cat']),
      _EmojiDefinition(
        character: '🐭',
        keywords: ['mouse face', 'rodent', 'mouse'],
      ),
      _EmojiDefinition(
        character: '🐹',
        keywords: ['hamster face', 'pet', 'hamster'],
      ),
      _EmojiDefinition(
        character: '🐰',
        keywords: ['rabbit face', 'bunny', 'rabbit'],
      ),
      _EmojiDefinition(
        character: '🦊',
        keywords: ['fox face', 'clever', 'fox'],
      ),
      _EmojiDefinition(
        character: '🐻',
        keywords: ['bear face', 'bear', 'animal'],
      ),
      _EmojiDefinition(
        character: '🐼',
        keywords: ['panda face', 'panda', 'bear'],
      ),
      _EmojiDefinition(
        character: '🐨',
        keywords: ['koala face', 'koala', 'bear'],
      ),
      _EmojiDefinition(
        character: '🐯',
        keywords: ['tiger face', 'tiger', 'wild'],
      ),
      _EmojiDefinition(
        character: '🦁',
        keywords: ['lion face', 'lion', 'king of jungle'],
      ),
      _EmojiDefinition(character: '🐮', keywords: ['cow face', 'cow', 'farm']),
      _EmojiDefinition(character: '🐷', keywords: ['pig face', 'pig', 'farm']),
      _EmojiDefinition(
        character: '🐸',
        keywords: ['frog face', 'frog', 'amphibian'],
      ),
      _EmojiDefinition(
        character: '🐵',
        keywords: ['monkey face', 'monkey', 'primate'],
      ),
      _EmojiDefinition(
        character: '🙈',
        keywords: ['see-no-evil', 'monkey', 'oops'],
      ),
      _EmojiDefinition(
        character: '🙉',
        keywords: ['hear-no-evil', 'monkey', 'oops'],
      ),
      _EmojiDefinition(
        character: '🙊',
        keywords: ['speak-no-evil', 'monkey', 'oops'],
      ),
      _EmojiDefinition(character: '🐔', keywords: ['chicken', 'hen', 'bird']),
      _EmojiDefinition(character: '🐧', keywords: ['penguin', 'bird', 'cold']),
      _EmojiDefinition(character: '🐦', keywords: ['bird', 'tweet', 'feather']),
      _EmojiDefinition(character: '🐤', keywords: ['chick', 'bird', 'baby']),
      _EmojiDefinition(
        character: '🐣',
        keywords: ['hatching chick', 'bird', 'egg'],
      ),
      _EmojiDefinition(character: '🦆', keywords: ['duck', 'bird', 'pond']),
      _EmojiDefinition(
        character: '🦋',
        keywords: ['butterfly', 'insect', 'beautiful'],
      ),
      _EmojiDefinition(
        character: '🐛',
        keywords: ['bug', 'insect', 'caterpillar'],
      ),
      _EmojiDefinition(
        character: '🐞',
        keywords: ['lady beetle', 'bug', 'insect'],
      ),
      _EmojiDefinition(
        character: '🦟',
        keywords: ['mosquito', 'bug', 'insect'],
      ),
      _EmojiDefinition(
        character: '🦂',
        keywords: ['scorpion', 'insect', 'stinger'],
      ),
      _EmojiDefinition(
        character: '🐢',
        keywords: ['turtle', 'reptile', 'slow'],
      ),
      _EmojiDefinition(
        character: '🐍',
        keywords: ['snake', 'reptile', 'danger'],
      ),
      _EmojiDefinition(
        character: '🦎',
        keywords: ['lizard', 'reptile', 'gecko'],
      ),
      _EmojiDefinition(
        character: '🦖',
        keywords: ['t-rex', 'dinosaur', 'prehistoric'],
      ),
      _EmojiDefinition(
        character: '🌵',
        keywords: ['cactus', 'plant', 'desert'],
      ),
      _EmojiDefinition(
        character: '🌲',
        keywords: ['evergreen tree', 'tree', 'nature'],
      ),
      _EmojiDefinition(
        character: '🌳',
        keywords: ['deciduous tree', 'tree', 'nature'],
      ),
      _EmojiDefinition(
        character: '🌴',
        keywords: ['palm tree', 'tropical', 'vacation'],
      ),
      _EmojiDefinition(
        character: '🌻',
        keywords: ['sunflower', 'flower', 'plant'],
      ),
      _EmojiDefinition(
        character: '🌺',
        keywords: ['hibiscus', 'flower', 'tropical'],
      ),
    ],
  ),
  _EmojiGroup(
    id: 'food',
    title: 'Food & Drink',
    icon: '🍔',
    emojis: [
      _EmojiDefinition(
        character: '🍎',
        keywords: ['red apple', 'fruit', 'apple'],
      ),
      _EmojiDefinition(character: '🍋', keywords: ['lemon', 'fruit', 'sour']),
      _EmojiDefinition(
        character: '🍌',
        keywords: ['banana', 'fruit', 'yellow'],
      ),
      _EmojiDefinition(
        character: '🍉',
        keywords: ['watermelon', 'fruit', 'refreshing'],
      ),
      _EmojiDefinition(character: '🍇', keywords: ['grapes', 'fruit', 'vine']),
      _EmojiDefinition(
        character: '🍓',
        keywords: ['strawberry', 'fruit', 'berry'],
      ),
      _EmojiDefinition(
        character: '🍒',
        keywords: ['cherries', 'fruit', 'berry'],
      ),
      _EmojiDefinition(character: '🍑', keywords: ['peach', 'fruit', 'sweet']),
      _EmojiDefinition(
        character: '🥭',
        keywords: ['mango', 'fruit', 'tropical'],
      ),
      _EmojiDefinition(
        character: '🍍',
        keywords: ['pineapple', 'fruit', 'tropical'],
      ),
      _EmojiDefinition(
        character: '🥥',
        keywords: ['coconut', 'fruit', 'tropical'],
      ),
      _EmojiDefinition(character: '🥝', keywords: ['kiwi', 'fruit', 'green']),
      _EmojiDefinition(
        character: '🍅',
        keywords: ['tomato', 'vegetable', 'fruit'],
      ),
      _EmojiDefinition(
        character: '🥑',
        keywords: ['avocado', 'fruit', 'green'],
      ),
      _EmojiDefinition(
        character: '🥦',
        keywords: ['broccoli', 'vegetable', 'green'],
      ),
      _EmojiDefinition(
        character: '🥕',
        keywords: ['carrot', 'vegetable', 'orange'],
      ),
      _EmojiDefinition(
        character: '🌽',
        keywords: ['ear of corn', 'corn', 'vegetable'],
      ),
      _EmojiDefinition(character: '🍞', keywords: ['bread', 'carb', 'toast']),
      _EmojiDefinition(
        character: '🥐',
        keywords: ['croissant', 'bread', 'french'],
      ),
      _EmojiDefinition(
        character: '🥯',
        keywords: ['bagel', 'bread', 'breakfast'],
      ),
      _EmojiDefinition(
        character: '🥞',
        keywords: ['pancakes', 'breakfast', 'syrup'],
      ),
      _EmojiDefinition(
        character: '🧇',
        keywords: ['waffle', 'breakfast', 'syrup'],
      ),
      _EmojiDefinition(
        character: '🥓',
        keywords: ['bacon', 'meat', 'breakfast'],
      ),
      _EmojiDefinition(
        character: '🥩',
        keywords: ['cut of meat', 'steak', 'protein'],
      ),
      _EmojiDefinition(
        character: '🍗',
        keywords: ['poultry leg', 'chicken', 'meat'],
      ),
      _EmojiDefinition(
        character: '🍖',
        keywords: ['meat on bone', 'meat', 'protein'],
      ),
      _EmojiDefinition(
        character: '🍔',
        keywords: ['hamburger', 'burger', 'fast food'],
      ),
      _EmojiDefinition(
        character: '🍟',
        keywords: ['french fries', 'fries', 'fast food'],
      ),
      _EmojiDefinition(
        character: '🍕',
        keywords: ['pizza', 'slice', 'fast food'],
      ),
      _EmojiDefinition(
        character: '🌭',
        keywords: ['hot dog', 'fast food', 'meal'],
      ),
      _EmojiDefinition(character: '🌮', keywords: ['taco', 'mexican', 'food']),
      _EmojiDefinition(
        character: '🌯',
        keywords: ['burrito', 'mexican', 'wrap'],
      ),
      _EmojiDefinition(
        character: '🥗',
        keywords: ['green salad', 'healthy', 'food'],
      ),
      _EmojiDefinition(
        character: '🍣',
        keywords: ['sushi', 'japanese', 'food'],
      ),
      _EmojiDefinition(
        character: '🍜',
        keywords: ['steaming bowl', 'noodles', 'ramen'],
      ),
      _EmojiDefinition(
        character: '🍱',
        keywords: ['bento box', 'japanese', 'lunch'],
      ),
      _EmojiDefinition(
        character: '🍦',
        keywords: ['soft ice cream', 'dessert', 'sweet'],
      ),
      _EmojiDefinition(
        character: '🍩',
        keywords: ['doughnut', 'dessert', 'sweet'],
      ),
      _EmojiDefinition(
        character: '🍪',
        keywords: ['cookie', 'dessert', 'sweet'],
      ),
      _EmojiDefinition(
        character: '🎂',
        keywords: ['birthday cake', 'dessert', 'celebrate'],
      ),
      _EmojiDefinition(
        character: '🍫',
        keywords: ['chocolate bar', 'dessert', 'sweet'],
      ),
      _EmojiDefinition(
        character: '🍿',
        keywords: ['popcorn', 'snack', 'movie'],
      ),
      _EmojiDefinition(
        character: '🍺',
        keywords: ['beer mug', 'drink', 'beer'],
      ),
      _EmojiDefinition(
        character: '🍷',
        keywords: ['wine glass', 'drink', 'wine'],
      ),
      _EmojiDefinition(
        character: '🍸',
        keywords: ['cocktail glass', 'drink', 'martini'],
      ),
      _EmojiDefinition(
        character: '🥤',
        keywords: ['cup with straw', 'drink', 'soda'],
      ),
      _EmojiDefinition(
        character: '☕',
        keywords: ['hot beverage', 'coffee', 'tea'],
      ),
    ],
  ),
  _EmojiGroup(
    id: 'activity',
    title: 'Activities',
    icon: '🏀',
    emojis: [
      _EmojiDefinition(
        character: '⚽',
        keywords: ['soccer ball', 'football', 'sport'],
      ),
      _EmojiDefinition(
        character: '🏀',
        keywords: ['basketball', 'sport', 'ball'],
      ),
      _EmojiDefinition(
        character: '🏈',
        keywords: ['american football', 'sport', 'ball'],
      ),
      _EmojiDefinition(character: '⚾', keywords: ['baseball', 'sport', 'ball']),
      _EmojiDefinition(character: '🎾', keywords: ['tennis', 'sport', 'ball']),
      _EmojiDefinition(
        character: '🏐',
        keywords: ['volleyball', 'sport', 'ball'],
      ),
      _EmojiDefinition(
        character: '🏉',
        keywords: ['rugby football', 'sport', 'ball'],
      ),
      _EmojiDefinition(
        character: '🥎',
        keywords: ['softball', 'sport', 'ball'],
      ),
      _EmojiDefinition(
        character: '🎱',
        keywords: ['pool 8 ball', 'billiards', 'game'],
      ),
      _EmojiDefinition(
        character: '🏓',
        keywords: ['ping pong', 'table tennis', 'sport'],
      ),
      _EmojiDefinition(
        character: '🏸',
        keywords: ['badminton', 'birdie', 'sport'],
      ),
      _EmojiDefinition(
        character: '🥅',
        keywords: ['goal net', 'sports', 'goal'],
      ),
      _EmojiDefinition(
        character: '⛳',
        keywords: ['flag in hole', 'golf', 'sport'],
      ),
      _EmojiDefinition(
        character: '🏹',
        keywords: ['bow and arrow', 'archery', 'sport'],
      ),
      _EmojiDefinition(
        character: '🥊',
        keywords: ['boxing glove', 'boxing', 'sport'],
      ),
      _EmojiDefinition(
        character: '🥋',
        keywords: ['martial arts uniform', 'karate', 'judo'],
      ),
      _EmojiDefinition(
        character: '🎽',
        keywords: ['running shirt', 'marathon', 'exercise'],
      ),
      _EmojiDefinition(
        character: '🛹',
        keywords: ['skateboard', 'sport', 'skating'],
      ),
      _EmojiDefinition(character: '🛷', keywords: ['sled', 'winter', 'sport']),
      _EmojiDefinition(character: '🎿', keywords: ['skis', 'winter', 'sport']),
      _EmojiDefinition(
        character: '⛸️',
        keywords: ['ice skate', 'winter', 'sport'],
      ),
      _EmojiDefinition(
        character: '🥌',
        keywords: ['curling stone', 'winter', 'sport'],
      ),
      _EmojiDefinition(
        character: '🚴‍♂️',
        keywords: ['man biking', 'cycling', 'sport'],
      ),
      _EmojiDefinition(
        character: '🏇',
        keywords: ['horse racing', 'sport', 'jockey'],
      ),
      _EmojiDefinition(character: '🏆', keywords: ['trophy', 'award', 'win']),
      _EmojiDefinition(
        character: '🎖️',
        keywords: ['military medal', 'award', 'honor'],
      ),
      _EmojiDefinition(
        character: '🥇',
        keywords: ['1st place medal', 'gold', 'winner'],
      ),
      _EmojiDefinition(
        character: '🥈',
        keywords: ['2nd place medal', 'silver', 'winner'],
      ),
      _EmojiDefinition(
        character: '🥉',
        keywords: ['3rd place medal', 'bronze', 'winner'],
      ),
      _EmojiDefinition(
        character: '🎯',
        keywords: ['bullseye', 'dart board', 'target'],
      ),
      _EmojiDefinition(
        character: '🎮',
        keywords: ['video game', 'controller', 'play'],
      ),
      _EmojiDefinition(
        character: '🎲',
        keywords: ['game die', 'board game', 'chance'],
      ),
      _EmojiDefinition(
        character: '🧩',
        keywords: ['puzzle piece', 'jigsaw', 'game'],
      ),
      _EmojiDefinition(
        character: '♟️',
        keywords: ['chess pawn', 'board game', 'strategy'],
      ),
      _EmojiDefinition(
        character: '🎭',
        keywords: ['performing arts', 'theater', 'drama'],
      ),
      _EmojiDefinition(
        character: '🎨',
        keywords: ['artist palette', 'paint', 'creative'],
      ),
      _EmojiDefinition(
        character: '🎬',
        keywords: ['clapper board', 'film', 'movie'],
      ),
      _EmojiDefinition(
        character: '🎤',
        keywords: ['microphone', 'sing', 'music'],
      ),
      _EmojiDefinition(
        character: '🎧',
        keywords: ['headphone', 'music', 'listen'],
      ),
      _EmojiDefinition(
        character: '🎹',
        keywords: ['musical keyboard', 'piano', 'music'],
      ),
      _EmojiDefinition(character: '🥁', keywords: ['drum', 'music', 'beat']),
      _EmojiDefinition(
        character: '🎷',
        keywords: ['saxophone', 'music', 'jazz'],
      ),
      _EmojiDefinition(character: '🎺', keywords: ['trumpet', 'music', 'band']),
      _EmojiDefinition(character: '🎸', keywords: ['guitar', 'music', 'rock']),
    ],
  ),
  _EmojiGroup(
    id: 'travel',
    title: 'Travel & Places',
    icon: '🚗',
    emojis: [
      _EmojiDefinition(
        character: '🚗',
        keywords: ['car', 'automobile', 'drive'],
      ),
      _EmojiDefinition(character: '🚕', keywords: ['taxi', 'cab', 'ride']),
      _EmojiDefinition(
        character: '🚙',
        keywords: ['sport utility vehicle', 'suv', 'car'],
      ),
      _EmojiDefinition(
        character: '🚌',
        keywords: ['bus', 'public transit', 'ride'],
      ),
      _EmojiDefinition(
        character: '🚎',
        keywords: ['trolleybus', 'transit', 'ride'],
      ),
      _EmojiDefinition(
        character: '🏎️',
        keywords: ['racing car', 'race', 'fast'],
      ),
      _EmojiDefinition(
        character: '🚓',
        keywords: ['police car', 'law', 'vehicle'],
      ),
      _EmojiDefinition(
        character: '🚑',
        keywords: ['ambulance', 'emergency', 'vehicle'],
      ),
      _EmojiDefinition(
        character: '🚒',
        keywords: ['fire engine', 'fire', 'vehicle'],
      ),
      _EmojiDefinition(
        character: '🚜',
        keywords: ['tractor', 'farm', 'vehicle'],
      ),
      _EmojiDefinition(character: '🚲', keywords: ['bicycle', 'bike', 'ride']),
      _EmojiDefinition(
        character: '🛵',
        keywords: ['motor scooter', 'scooter', 'ride'],
      ),
      _EmojiDefinition(
        character: '🏍️',
        keywords: ['motorcycle', 'bike', 'ride'],
      ),
      _EmojiDefinition(
        character: '🛺',
        keywords: ['auto rickshaw', 'tuk tuk', 'ride'],
      ),
      _EmojiDefinition(
        character: '🚃',
        keywords: ['railway car', 'train', 'transport'],
      ),
      _EmojiDefinition(
        character: '🚆',
        keywords: ['train', 'transport', 'rail'],
      ),
      _EmojiDefinition(
        character: '🚄',
        keywords: ['high-speed train', 'bullet train', 'transport'],
      ),
      _EmojiDefinition(
        character: '✈️',
        keywords: ['airplane', 'flight', 'travel'],
      ),
      _EmojiDefinition(
        character: '🛩️',
        keywords: ['small airplane', 'flight', 'travel'],
      ),
      _EmojiDefinition(
        character: '🛫',
        keywords: ['airplane departure', 'takeoff', 'flight'],
      ),
      _EmojiDefinition(
        character: '🛬',
        keywords: ['airplane arrival', 'landing', 'flight'],
      ),
      _EmojiDefinition(
        character: '🪂',
        keywords: ['parachute', 'skydive', 'air'],
      ),
      _EmojiDefinition(
        character: '🚁',
        keywords: ['helicopter', 'air', 'travel'],
      ),
      _EmojiDefinition(
        character: '🚀',
        keywords: ['rocket', 'space', 'launch'],
      ),
      _EmojiDefinition(
        character: '🛸',
        keywords: ['flying saucer', 'ufo', 'space'],
      ),
      _EmojiDefinition(character: '⛵', keywords: ['sailboat', 'boat', 'water']),
      _EmojiDefinition(
        character: '🚤',
        keywords: ['speedboat', 'boat', 'water'],
      ),
      _EmojiDefinition(
        character: '🛥️',
        keywords: ['motor boat', 'water', 'travel'],
      ),
      _EmojiDefinition(
        character: '🛳️',
        keywords: ['passenger ship', 'cruise', 'boat'],
      ),
      _EmojiDefinition(
        character: '⚓',
        keywords: ['anchor', 'boat', 'nautical'],
      ),
      _EmojiDefinition(
        character: '🗽',
        keywords: ['statue of liberty', 'landmark', 'new york'],
      ),
      _EmojiDefinition(
        character: '🗼',
        keywords: ['tokyo tower', 'landmark', 'japan'],
      ),
      _EmojiDefinition(
        character: '🏰',
        keywords: ['castle', 'landmark', 'travel'],
      ),
      _EmojiDefinition(
        character: '🏯',
        keywords: ['japanese castle', 'landmark', 'travel'],
      ),
      _EmojiDefinition(
        character: '🌋',
        keywords: ['volcano', 'mountain', 'nature'],
      ),
      _EmojiDefinition(
        character: '🗻',
        keywords: ['mount fuji', 'mountain', 'japan'],
      ),
      _EmojiDefinition(
        character: '🏖️',
        keywords: ['beach umbrella', 'vacation', 'sun'],
      ),
      _EmojiDefinition(
        character: '🏜️',
        keywords: ['desert', 'sand', 'travel'],
      ),
      _EmojiDefinition(
        character: '🏝️',
        keywords: ['desert island', 'beach', 'vacation'],
      ),
      _EmojiDefinition(character: '🌁', keywords: ['foggy', 'weather', 'city']),
    ],
  ),
  _EmojiGroup(
    id: 'objects',
    title: 'Objects',
    icon: '💡',
    emojis: [
      _EmojiDefinition(character: '⌚', keywords: ['watch', 'time', 'clock']),
      _EmojiDefinition(
        character: '📱',
        keywords: ['mobile phone', 'smartphone', 'device'],
      ),
      _EmojiDefinition(
        character: '💻',
        keywords: ['laptop', 'computer', 'device'],
      ),
      _EmojiDefinition(
        character: '⌨️',
        keywords: ['keyboard', 'computer', 'typing'],
      ),
      _EmojiDefinition(
        character: '🖥️',
        keywords: ['desktop computer', 'monitor', 'device'],
      ),
      _EmojiDefinition(
        character: '🖨️',
        keywords: ['printer', 'device', 'office'],
      ),
      _EmojiDefinition(
        character: '🖱️',
        keywords: ['computer mouse', 'device', 'pointer'],
      ),
      _EmojiDefinition(
        character: '🕹️',
        keywords: ['joystick', 'game', 'controller'],
      ),
      _EmojiDefinition(
        character: '💽',
        keywords: ['computer disk', 'storage', 'retro'],
      ),
      _EmojiDefinition(
        character: '💾',
        keywords: ['floppy disk', 'storage', 'save'],
      ),
      _EmojiDefinition(
        character: '💿',
        keywords: ['optical disk', 'cd', 'music'],
      ),
      _EmojiDefinition(character: '📀', keywords: ['dvd', 'storage', 'disk']),
      _EmojiDefinition(
        character: '📷',
        keywords: ['camera', 'photo', 'picture'],
      ),
      _EmojiDefinition(
        character: '📸',
        keywords: ['camera flash', 'photo', 'picture'],
      ),
      _EmojiDefinition(
        character: '🎥',
        keywords: ['movie camera', 'film', 'video'],
      ),
      _EmojiDefinition(
        character: '📺',
        keywords: ['television', 'tv', 'device'],
      ),
      _EmojiDefinition(
        character: '📻',
        keywords: ['radio', 'music', 'broadcast'],
      ),
      _EmojiDefinition(
        character: '🎙️',
        keywords: ['studio microphone', 'record', 'audio'],
      ),
      _EmojiDefinition(
        character: '🎚️',
        keywords: ['level slider', 'audio', 'control'],
      ),
      _EmojiDefinition(
        character: '🎛️',
        keywords: ['control knobs', 'audio', 'mixer'],
      ),
      _EmojiDefinition(
        character: '🔋',
        keywords: ['battery', 'charge', 'power'],
      ),
      _EmojiDefinition(
        character: '🔌',
        keywords: ['electric plug', 'power', 'cord'],
      ),
      _EmojiDefinition(
        character: '💡',
        keywords: ['light bulb', 'idea', 'bright'],
      ),
      _EmojiDefinition(
        character: '🔦',
        keywords: ['flashlight', 'torch', 'light'],
      ),
      _EmojiDefinition(character: '🕯️', keywords: ['candle', 'light', 'wax']),
      _EmojiDefinition(
        character: '🛋️',
        keywords: ['couch and lamp', 'furniture', 'sofa'],
      ),
      _EmojiDefinition(
        character: '🛏️',
        keywords: ['bed', 'sleep', 'furniture'],
      ),
      _EmojiDefinition(character: '🚪', keywords: ['door', 'entry', 'exit']),
      _EmojiDefinition(
        character: '🛎️',
        keywords: ['bellhop bell', 'service', 'bell'],
      ),
      _EmojiDefinition(
        character: '🧳',
        keywords: ['luggage', 'suitcase', 'travel'],
      ),
      _EmojiDefinition(character: '⚙️', keywords: ['gear', 'settings', 'cog']),
      _EmojiDefinition(
        character: '🧰',
        keywords: ['toolbox', 'tools', 'repair'],
      ),
      _EmojiDefinition(
        character: '🛠️',
        keywords: ['hammer and wrench', 'tools', 'build'],
      ),
      _EmojiDefinition(
        character: '🪛',
        keywords: ['screwdriver', 'tools', 'repair'],
      ),
      _EmojiDefinition(character: '🔨', keywords: ['hammer', 'tool', 'build']),
      _EmojiDefinition(
        character: '⚒️',
        keywords: ['hammer and pick', 'tool', 'mine'],
      ),
      _EmojiDefinition(
        character: '🪚',
        keywords: ['carpentry saw', 'tool', 'cut'],
      ),
      _EmojiDefinition(
        character: '🧱',
        keywords: ['brick', 'construction', 'build'],
      ),
      _EmojiDefinition(
        character: '🧲',
        keywords: ['magnet', 'attract', 'magnetic'],
      ),
      _EmojiDefinition(character: '🪜', keywords: ['ladder', 'climb', 'tool']),
      _EmojiDefinition(
        character: '🔒',
        keywords: ['locked', 'secure', 'closed'],
      ),
      _EmojiDefinition(
        character: '🔓',
        keywords: ['unlocked', 'open', 'security'],
      ),
      _EmojiDefinition(character: '🔑', keywords: ['key', 'unlock', 'access']),
      _EmojiDefinition(
        character: '🗝️',
        keywords: ['old key', 'unlock', 'vintage'],
      ),
    ],
  ),
  _EmojiGroup(
    id: 'symbols',
    title: 'Symbols',
    icon: '#',
    emojis: [
      _EmojiDefinition(
        character: '❤️',
        keywords: ['red heart', 'love', 'like'],
      ),
      _EmojiDefinition(
        character: '🧡',
        keywords: ['orange heart', 'love', 'affection'],
      ),
      _EmojiDefinition(
        character: '💛',
        keywords: ['yellow heart', 'love', 'friendship'],
      ),
      _EmojiDefinition(
        character: '💚',
        keywords: ['green heart', 'love', 'envy'],
      ),
      _EmojiDefinition(
        character: '💙',
        keywords: ['blue heart', 'love', 'loyalty'],
      ),
      _EmojiDefinition(
        character: '💜',
        keywords: ['purple heart', 'love', 'care'],
      ),
      _EmojiDefinition(
        character: '🤎',
        keywords: ['brown heart', 'love', 'warm'],
      ),
      _EmojiDefinition(
        character: '🖤',
        keywords: ['black heart', 'love', 'dark'],
      ),
      _EmojiDefinition(
        character: '🤍',
        keywords: ['white heart', 'love', 'pure'],
      ),
      _EmojiDefinition(
        character: '💔',
        keywords: ['broken heart', 'heartbreak', 'sad'],
      ),
      _EmojiDefinition(
        character: '❣️',
        keywords: ['heart exclamation', 'love', 'punctuation'],
      ),
      _EmojiDefinition(
        character: '💕',
        keywords: ['two hearts', 'love', 'affection'],
      ),
      _EmojiDefinition(
        character: '💞',
        keywords: ['revolving hearts', 'love', 'affection'],
      ),
      _EmojiDefinition(
        character: '💓',
        keywords: ['beating heart', 'heartbeat', 'love'],
      ),
      _EmojiDefinition(
        character: '💗',
        keywords: ['growing heart', 'love', 'pink'],
      ),
      _EmojiDefinition(
        character: '💖',
        keywords: ['sparkling heart', 'love', 'glitter'],
      ),
      _EmojiDefinition(
        character: '💘',
        keywords: ['heart arrow', 'love', 'cupid'],
      ),
      _EmojiDefinition(
        character: '💝',
        keywords: ['heart ribbon', 'gift', 'love'],
      ),
      _EmojiDefinition(
        character: '💟',
        keywords: ['heart decoration', 'love', 'ornament'],
      ),
      _EmojiDefinition(
        character: '🔞',
        keywords: ['no minors', '18', 'restricted'],
      ),
      _EmojiDefinition(
        character: '♻️',
        keywords: ['recycling', 'environment', 'loop'],
      ),
      _EmojiDefinition(
        character: '⚜️',
        keywords: ['fleur-de-lis', 'symbol', 'royal'],
      ),
      _EmojiDefinition(
        character: '🔱',
        keywords: ['trident emblem', 'symbol', 'sea'],
      ),
      _EmojiDefinition(
        character: '⚠️',
        keywords: ['warning', 'alert', 'caution'],
      ),
      _EmojiDefinition(
        character: '🚸',
        keywords: ['children crossing', 'warning', 'sign'],
      ),
      _EmojiDefinition(
        character: '⛔',
        keywords: ['no entry', 'prohibited', 'sign'],
      ),
      _EmojiDefinition(character: '🚫', keywords: ['prohibited', 'no', 'sign']),
      _EmojiDefinition(
        character: '✅',
        keywords: ['check mark button', 'success', 'confirm'],
      ),
      _EmojiDefinition(
        character: '☑️',
        keywords: ['check box', 'select', 'task'],
      ),
      _EmojiDefinition(
        character: '✔️',
        keywords: ['check mark', 'tick', 'confirm'],
      ),
      _EmojiDefinition(
        character: '❌',
        keywords: ['cross mark', 'cancel', 'no'],
      ),
      _EmojiDefinition(
        character: '❎',
        keywords: ['cross mark button', 'cancel', 'no'],
      ),
      _EmojiDefinition(character: '➕', keywords: ['plus', 'add', 'math']),
      _EmojiDefinition(character: '➖', keywords: ['minus', 'subtract', 'math']),
      _EmojiDefinition(character: '➗', keywords: ['divide', 'math', 'symbol']),
      _EmojiDefinition(
        character: '✖️',
        keywords: ['multiplication', 'math', 'symbol'],
      ),
      _EmojiDefinition(
        character: '❓',
        keywords: ['question mark', 'help', 'what'],
      ),
      _EmojiDefinition(
        character: '❔',
        keywords: ['white question mark', 'help', 'what'],
      ),
      _EmojiDefinition(
        character: '❗',
        keywords: ['exclamation mark', 'alert', 'attention'],
      ),
      _EmojiDefinition(
        character: '❕',
        keywords: ['white exclamation', 'attention', 'notice'],
      ),
      _EmojiDefinition(
        character: '🔔',
        keywords: ['bell', 'notification', 'sound'],
      ),
      _EmojiDefinition(
        character: '🔕',
        keywords: ['bell with slash', 'mute', 'silent'],
      ),
      _EmojiDefinition(
        character: '🔊',
        keywords: ['speaker high volume', 'sound', 'loud'],
      ),
      _EmojiDefinition(
        character: '🔇',
        keywords: ['muted speaker', 'mute', 'silent'],
      ),
      _EmojiDefinition(
        character: '🔗',
        keywords: ['link', 'url', 'connection'],
      ),
      _EmojiDefinition(
        character: '🧷',
        keywords: ['safety pin', 'pin', 'clip'],
      ),
    ],
  ),
  _EmojiGroup(
    id: 'flags',
    title: 'Flags',
    icon: '🏳️',
    emojis: [
      _EmojiDefinition(
        character: '🏳️',
        keywords: ['white flag', 'peace', 'flag'],
      ),
      _EmojiDefinition(
        character: '🏴',
        keywords: ['black flag', 'pirate', 'flag'],
      ),
      _EmojiDefinition(
        character: '🏁',
        keywords: ['chequered flag', 'finish', 'race'],
      ),
      _EmojiDefinition(
        character: '🚩',
        keywords: ['triangular flag', 'post', 'mark'],
      ),
      _EmojiDefinition(
        character: '🏴‍☠️',
        keywords: ['pirate flag', 'skull', 'crossbones'],
      ),
      _EmojiDefinition(
        character: '🏳️‍🌈',
        keywords: ['rainbow flag', 'pride', 'flag'],
      ),
      _EmojiDefinition(
        character: '🏳️‍⚧️',
        keywords: ['transgender flag', 'pride', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇮🇳',
        keywords: ['india flag', 'india', 'country'],
      ),
      _EmojiDefinition(
        character: '🇺🇸',
        keywords: ['united states flag', 'usa', 'country'],
      ),
      _EmojiDefinition(
        character: '🇬🇧',
        keywords: ['united kingdom flag', 'uk', 'country'],
      ),
      _EmojiDefinition(
        character: '🇦🇺',
        keywords: ['australia flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇨🇦',
        keywords: ['canada flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇧🇷',
        keywords: ['brazil flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇯🇵',
        keywords: ['japan flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇫🇷',
        keywords: ['france flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇩🇪',
        keywords: ['germany flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇪🇸',
        keywords: ['spain flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇮🇹',
        keywords: ['italy flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇨🇳',
        keywords: ['china flag', 'country', 'flag'],
      ),
      _EmojiDefinition(
        character: '🇰🇷',
        keywords: ['south korea flag', 'country', 'flag'],
      ),
    ],
  ),
];
