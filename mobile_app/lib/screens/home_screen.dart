import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detail_screen.dart';
import '../services/detect_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<Color> _accents = [
    Color(0xFFFF7043),
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
    Color(0xFFEC407A),
    Color(0xFFFFA726),
    Color(0xFF66BB6A),
    Color(0xFF29B6F6),
  ];

  static IconData _iconFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('paper')) return Icons.description_rounded;
    if (c.contains('card')) return Icons.inventory_2_rounded;
    if (c.contains('clay')) return Icons.bubble_chart_rounded;
    if (c.contains('paint') || c.contains('draw')) return Icons.brush_rounded;
    if (c.contains('recycle') || c.contains('waste')) return Icons.recycling_rounded;
    if (c.contains('origami')) return Icons.flutter_dash_rounded;
    if (c.contains('bottle')) return Icons.local_drink_rounded;
    if (c.contains('fabric') || c.contains('cloth')) return Icons.checkroom_rounded;
    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('craft').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No crafts found in database!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

final Map<String, List<Map<String, dynamic>>> categorized = {};          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final category = data['category'] ?? 'Other Crafts';
            categorized.putIfAbsent(category, () => []).add(data);
          }
          final entries = categorized.entries.toList();
          final totalCrafts = snapshot.data!.docs.length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  totalCrafts: totalCrafts,
                  totalCategories: entries.length,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final accent = _accents[i % _accents.length];
                  return _CategorySection(
                    name: entries[i].key,
                    crafts: entries[i].value,
                    accent: accent,
                    icon: _iconFor(entries[i].key),
                    index: i,
                  );
                }, childCount: entries.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          );
        },
      ),
      floatingActionButton: const _PulsingScanButton(),
    );
  }
}

// ===================== HEADER =====================
class _Header extends StatelessWidget {
  final int totalCrafts;
  final int totalCategories;
  const _Header({required this.totalCrafts, required this.totalCategories});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, -30 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF66BB6A), Color(0xFF26C6DA)],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: -20, top: -30, child: _bubble(110, 0.12)),
            Positioned(right: 60, bottom: -20, child: _bubble(60, 0.15)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.waving_hand_rounded,
                      color: Color(0xFFFFEB3B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Hello, little artist!',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.palette_rounded, color: Colors.white, size: 34),
                    SizedBox(width: 10),
                    Text(
                      'Kids Hand Craft',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'What shall we make today?',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statChip(
                      Icons.category_rounded,
                      '$totalCategories Categories',
                    ),
                    const SizedBox(width: 10),
                    _statChip(
                      Icons.auto_awesome_rounded,
                      '$totalCrafts Crafts',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bubble(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );

  static Widget _statChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ===================== CATEGORY SECTION =====================
class _CategorySection extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> crafts;
  final Color accent;
  final IconData icon;
  final int index;

  const _CategorySection({
    required this.name,
    required this.crafts,
    required this.accent,
    required this.icon,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 150),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - v)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swipe_rounded, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        '${crafts.length}',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 380,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: crafts.length,
              itemBuilder: (context, i) =>
                  _CraftCard(craft: crafts[i], accent: accent, index: i),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== CRAFT CARD =====================
class _CraftCard extends StatefulWidget {
  final Map<String, dynamic> craft;
  final Color accent;
  final int index;

  const _CraftCard({
    required this.craft,
    required this.accent,
    required this.index,
  });

  @override
  State<_CraftCard> createState() => _CraftCardState();
}

class _CraftCardState extends State<_CraftCard> {
  bool _pressed = false;
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + widget.index * 120),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(60 * (1 - v), 0),
          child: child,
        ),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (_, _, _) => DetailScreen(craft: widget.craft),
                transitionsBuilder: (_, anim, _, child) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: Container(
            width: 190,
            margin: const EdgeInsets.only(right: 16, top: 4, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.28),
                          accent.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            widget.craft['imagePath'] ??
                                'assets/images/placeholder.jpg',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 44,
                                color: accent,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _liked = !_liked),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (c, a) =>
                                      ScaleTransition(scale: a, child: c),
                                  child: Icon(
                                    _liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    key: ValueKey(_liked),
                                    size: 20,
                                    color: _liked
                                        ? const Color(0xFFE91E63)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 10, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.craft['title'] ?? 'Craft',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.2,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.75)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== PULSING SCAN BUTTON =====================
class _PulsingScanButton extends StatefulWidget {
  const _PulsingScanButton();

  @override
  State<_PulsingScanButton> createState() => _PulsingScanButtonState();
}

class _PulsingScanButtonState extends State<_PulsingScanButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.scale(scale: 1.0 + 0.05 * _c.value, child: child),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DetectScreen()),
            );
          },
          backgroundColor: const Color(0xFF2ECC71),
          elevation: 0,
          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
          label: const Text(
            'Scan & Find',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}