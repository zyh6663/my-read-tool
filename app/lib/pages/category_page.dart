import 'package:flutter/material.dart';

import '../animated_glass.dart';
import '../glass_widgets.dart';
import '../reading_page.dart';
import '../services/search_service.dart';

/// 分类关键词映射表（顺序匹配，命中第一个就归类）
const Map<String, List<String>> _categoryKeywords = {
  "乱伦": [
    "母亲", "妈妈", "岳母", "外婆", "奶奶", "婶婶", "姨妈", "姑姑", "表姐",
    "表妹", "堂姐", "堂妹", "姐姐", "妹妹", "女儿", "继母", "养母", "干妈",
    "岳母", "嫂子", "弟媳", "婶婶", "舅妈", "阿姨", "小姨", "侄女", "外甥女",
    "嫂子", "弟妹", "继女", "养女",
  ],
  "调教": [
    "调教", "调校", "支配", "服从", "主人", "奴隶", "母狗", "驯化", "征服",
    "管教", "惩戒", "惩罚", "训诫", "调驯", "奴役", "掌控",
  ],
  "强暴": [
    "强奸", "强暴", "侵犯", "凌辱", "胁迫", "强推", "强行", "硬上", "强来",
    "强迫", "施暴", "摧残", "蹂躏", "用强",
  ],
  "NTR/绿帽": [
    "NTR", "ntr", "绿帽", "绿奴", "出轨", "偷情", "不伦", "背德", "寝取",
    "共享", "换妻", "献妻", "人妻", "偷吃", "外遇",
  ],
  "校园": [
    "校园", "学校", "老师", "学生", "教室", "课堂", "同桌", "学姐", "学妹",
    "学长", "学弟", "班长", "校花", "校草", "补习", "补课",
  ],
  "都市": [
    "都市", "总裁", "董事长", "老板", "上司", "下属", "同事", "秘书", "办公室",
    "职场", "公司", "白领", "金领", "总裁", "CEO", "经理",
  ],
  "后宫": [
    "后宫", "多女", "群芳", "众女", "妻妾", "全员", "全收", "无雷", "无郁闷",
    "全处全收", "三妻四妾", "众美", "美少女", "美妇",
  ],
  "仙侠/玄幻": [
    "仙", "侠", "修仙", "魔", "神", "仙帝", "仙尊", "天尊", "修士", "仙门",
    "宗门", "仙界", "灵", "道", "剑", "龙", "凤", "天尊", "仙王", "万界", "诸天",
  ],
  "武侠/江湖": [
    "武侠", "江湖", "武林", "侠客", "侠侣", "门派", "掌门", "大侠", "剑客",
    "刀客", "暗器", "内力", "轻功", "武当", "少林", "峨眉",
  ],
  "历史/宫廷": [
    "皇帝", "皇上", "帝王", "太子", "皇子", "王爷", "将军", "宰相", "大臣",
    "妃", "嫔", "贵人", "公主", "郡主", "宫女", "太监", "宫中", "后妃",
  ],
  "科幻/末世": [
    "科幻", "末世", "末日", "丧尸", "变异", "进化", "星际", "外星", "宇宙",
    "机甲", "基因", "克隆", "核战", "废土", "异形", "虫族",
  ],
  "系统/穿越": [
    "系统", "穿越", "重生", "转生", "附身", "夺舍", "穿书", "跨界", "位面",
    "异界", "异世界", "穿越者", "平行", "随身", "签到", "抽奖",
  ],
  "触手/异种": [
    "触手", "异形", "怪物", "魔物", "异种", "妖兽", "触须", "寄生", "改造",
    "兽人", "半兽", "人外", "魔物娘", "史莱姆",
  ],
  "凌辱/虐待": [
    "凌辱", "虐待", "SM", "sm", "折磨", "拷问", "羞辱", "屈辱", "玷污",
    "摧残", "踩踏", "践踏", "施虐", "受虐", "鞭打", "滴蜡", "捆绑", "束缚",
  ],
  "纯爱/甜文": [
    "纯爱", "纯情", "恋爱", "甜蜜", "甜文", "初恋", "纯真", "唯美", "治愈",
    "温馨", "暖文", "小甜", "狗粮", "双向奔赴", "纯纯",
  ],
  "女性视角": [
    "女频", "女主", "女性", "女尊", "大女主", "宫斗", "宅斗", "种田", "团宠",
    "锦鲤", "福妻", "娇妻", "女帝", "女皇", "长公主",
  ],
  "催眠/控制": [
    "催眠", "洗脑", "控制", "操控", "意识", "精神控制", "心理暗示", "修改记忆",
    "心智", "心灵", "操纵", "遥控",
  ],
  "暴露/露出": [
    "暴露", "露出", "走光", "裸奔", "裸体", "赤裸", "真空", "户外", "公共",
    "偷窥", "被看", "公然", "透明",
  ],
  "足控/腿控": [
    "足", "脚", "玉足", "美腿", "长腿", "丝袜", "黑丝", "白丝", "肉丝",
    "裸足", "足交", "恋足", "舔脚", "脚交",
  ],
  "萝莉/幼": [
    "萝莉", "幼女", "幼", "小萝莉", "小妹妹", "幼齿", "小女孩", "稚嫩",
    "娇小", "袖珍", "洋娃娃", "小天使",
  ],
  "熟女/人妻": [
    "熟女", "人妻", "少妇", "御姐", "熟妇", "美妇", "主妇", "太太", "夫人",
    "大嫂", "伯母", "婶婶", "老妇", "大娘",
  ],
  "巨乳/巨根": [
    "巨乳", "爆乳", "大奶", "豪乳", "大胸", "巨根", "大屌", "粗大", "大鸡巴",
    "大阴茎", "大肉棒", "雄伟",
  ],
  "扶她/伪娘": [
    "扶她", "扶他", "伪娘", "双性", "变性", "人妖", "TS", "futa", "Futa",
    "雌雄同体", "男娘", "药娘",
  ],
  "乡村/乡土": [
    "乡村", "农村", "乡下", "村庄", "田间", "农家", "山野", "山寨", "乡土",
    "村民", "农夫", "庄稼", "稻香", "田园",
  ],
  "BL/耽美": ["BL", "bl", "耽美", "纯爱", "腐", "男同", "gay", "攻", "受", "双男主", "双强", "年下", "年上", "ABO"],
};

/// 独立分类函数：按顺序匹配关键词，命中第一个就归入对应标签。
/// 都不命中则归入"其他"。
String classifyBook(String title) {
  title = title.replaceAll('.txt', '');
  if (title.isEmpty) return "其他";
  for (final entry in _categoryKeywords.entries) {
    for (final keyword in entry.value) {
      if (title.contains(keyword)) {
        return entry.key;
      }
    }
  }
  return "其他";
}

/// ----------------------------------------------------------------
/// 书籍条目（从搜索结果中提取的关键字段）
/// ----------------------------------------------------------------
class _BookItem {
  final int sourceId;
  final String sourceBookId;
  final String title;
  final String author;
  final String coverUrl;

  const _BookItem({
    required this.sourceId,
    required this.sourceBookId,
    required this.title,
    required this.author,
    required this.coverUrl,
  });

  factory _BookItem.fromSearchResult(SearchResult r) => _BookItem(
        sourceId: r.sourceId,
        sourceBookId: r.sourceBookId,
        title: r.title,
        author: r.author,
        coverUrl: r.coverUrl,
      );
}

/// ----------------------------------------------------------------
/// CategoryPage – 基于书名的自动分类浏览页
/// ----------------------------------------------------------------
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  bool _loading = true;
  String? _error;
  List<_BookItem> _allBooks = [];
  Map<String, List<_BookItem>> _grouped = {};
  String _selectedCategory = "全部";

  /// 所有出现过的分类（保持声明顺序）
  List<String> get _categories => [
        "全部",
        ..._categoryKeywords.keys.where((k) => _grouped.containsKey(k)),
        if (_grouped.containsKey("其他")) "其他",
      ];

  List<_BookItem> get _filteredBooks {
    if (_selectedCategory == "全部") {
      return _allBooks;
    }
    return _grouped[_selectedCategory] ?? [];
  }

  @override
  void initState() {
    super.initState();
    _fetchAndClassify();
  }

  /// 通过 RemoteListBooks 获取完整书库并自动归类
  Future<void> _fetchAndClassify() async {
    final merged = <_BookItem>[];

    try {
      final results = await SearchService.listRemoteBooks();
      for (final r in results) {
        merged.add(_BookItem.fromSearchResult(r));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '获取书库失败: ${e.toString().length > 200 ? e.toString().substring(0, 200) : e}';
      });
      return;
    }

    if (merged.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '未获取到任何书籍数据';
      });
      return;
    }

    _allBooks = merged;

    // 归类
    _grouped = {};
    for (final book in _allBooks) {
      final cat = classifyBook(book.title);
      _grouped.putIfAbsent(cat, () => []).add(book);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _allBooks.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _fetchAndClassify();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final chips = _categories;
    final books = _filteredBooks;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- 标题 ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SlideFadeIn(
              child: GlassPanel(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    '书籍分类',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---- 标签芯片（横向滚动） ----
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = chips[index];
                final selected = cat == _selectedCategory;
                final count = cat == "全部"
                    ? _allBooks.length
                    : (_grouped[cat]?.length ?? 0);

                return ChoiceChip(
                  label: Text('$cat ($count)'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ---- 书籍列表 ----
          Expanded(
            child: books.isEmpty
                ? Center(
                    child: Text(
                      '该分类下暂无书籍',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return _BookListTile(
                        book: book,
                        onTap: () => _onBookTap(context, book),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _onBookTap(BuildContext context, _BookItem book) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在获取《${book.title}》详情…'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final detail = await SearchService.getDetail(book.sourceId, book.sourceBookId);
      if (!mounted) return;
      if (!context.mounted) return;
      _showBookDetail(context, detail);
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取详情失败: $e')),
      );
    }
  }

  void _showBookDetail(BuildContext context, BookDetail detail) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                detail.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '作者: ${detail.author.isNotEmpty ? detail.author : '未知'}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),

              // 操作按钮：导入到书架 + 开始阅读
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importBookToShelf(detail),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('导入到书架'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _startReading(detail, ctx),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('开始阅读'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                '来源: ${detail.sourceName}  ·  共 ${detail.chapterCount} 章',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (detail.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  detail.description,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '目录 (前 ${detail.chapters.length > 50 ? '50' : detail.chapters.length} 章)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...detail.chapters.take(50).map(
                    (ch) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${ch.index}. ${ch.title}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
              if (detail.chapters.length > 50)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '… 还有 ${detail.chapters.length - 50} 章',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importBookToShelf(BookDetail detail) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在导入书籍…'), duration: Duration(seconds: 1)),
    );
    try {
      final res = await SearchService.importBook(detail.sourceId, detail.sourceBookId, autoAddToShelf: true);
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final progress = await SearchService.getProgress(res.taskId);
        if (progress.status == 'completed') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${detail.title}》已导入到书架')),
          );
          return;
        }
        if (progress.status == 'failed') {
          throw Exception(progress.error.isNotEmpty ? progress.error : '导入失败');
        }
      }
      throw Exception('导入超时');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  Future<void> _startReading(BookDetail detail, BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在准备阅读…'), duration: Duration(seconds: 1)),
    );
    try {
      final res = await SearchService.importBook(detail.sourceId, detail.sourceBookId, autoAddToShelf: true);
      int? bookId;
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final progress = await SearchService.getProgress(res.taskId);
        if (progress.status == 'completed') {
          bookId = progress.bookId;
          break;
        }
        if (progress.status == 'failed') {
          throw Exception(progress.error.isNotEmpty ? progress.error : '导入失败');
        }
      }
      if (bookId == null || bookId == 0) throw Exception('导入超时或未获取到书籍ID');
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReadingPage(bookId: bookId!, bookTitle: detail.title),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('准备阅读失败: $e')),
      );
    }
  }
}

/// ----------------------------------------------------------------
/// 书籍列表项组件
/// ----------------------------------------------------------------
class _BookListTile extends StatelessWidget {
  final _BookItem book;
  final VoidCallback onTap;

  const _BookListTile({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SlideFadeIn(
        child: GlassPanel(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 封面
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 60,
                      child: book.coverUrl.isNotEmpty
                          ? Image.network(
                              book.coverUrl,
                              fit: BoxFit.cover,
                              cacheWidth: 88,
                              cacheHeight: 120,
                              errorBuilder: (_, _, _) => _fallbackCover(theme),
                            )
                          : _fallbackCover(theme),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.author.isNotEmpty ? book.author : '未知作者',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackCover(ThemeData theme) {
    return Container(
      width: 44,
      height: 60,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Icon(
        Icons.menu_book,
        size: 24,
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
      ),
    );
  }
}