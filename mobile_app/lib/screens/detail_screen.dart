import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class DetailScreen extends StatefulWidget {
  final Map<String, dynamic> craft;

  const DetailScreen({super.key, required this.craft});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late YoutubePlayerController _controller;
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);
  bool _miniClosed = false;
  double _dockEnd = 1;

  final Set<int> _checked = {};
  bool _liked = false;

  static const List<Color> _palette = [
    Color(0xFFFF7043),
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
    Color(0xFFEC407A),
    Color(0xFFFFA726),
    Color(0xFF66BB6A),
    Color(0xFF29B6F6),
  ];

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void initState() {
    super.initState();

    String videoUrl = widget.craft['videoUrl'] ?? '';
    String? videoId = YoutubePlayer.convertUrlToId(videoUrl);

    _controller = YoutubePlayerController(
      initialVideoId: videoId ?? 'dQw4w9WgXcQ',
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        isLive: false,
        enableCaption: true,
      ),
    );

    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final o = _scroll.hasClients ? _scroll.offset : 0.0;
    _offset.value = o;
    if (_miniClosed && o < _dockEnd * 0.5) {
      setState(() => _miniClosed = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _offset.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _closeMini() {
    _controller.pause();
    setState(() => _miniClosed = true);
  }

  void _expandMini() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List materials = (widget.craft['materials'] as List?) ?? [];
    final String title = widget.craft['title'] ?? 'Craft Details';
    final String category = widget.craft['category'] ?? '';
    final String description = widget.craft['description'] ?? '';
    final double progress =
        materials.isEmpty ? 0 : _checked.length / materials.length;

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF2ECC71),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF2ECC71),
          handleColor: Color(0xFF69F0AE),
        ),
      ),
      builder: (context, player) {
        final media = MediaQuery.of(context);
        final screenW = media.size.width;
        final screenH = media.size.height;
        final safeTop = media.padding.top;
        final safeBottom = media.padding.bottom;

        final videoW = screenW - 32;
        final videoH = videoW * 9 / 16;
        final slotTop = safeTop + 8 + 40 + 16;
        _dockEnd = slotTop + videoH;

        const miniW = 200.0;
        final miniH = miniW * 9 / 16;
        final miniLeft = screenW - miniW - 16;
        final miniTop = screenH - miniH - 24 - safeBottom;

        return Scaffold(
          backgroundColor: const Color(0xFFF4FAF2),
          body: Stack(
            children: [
              // ---------- Scrollable page ----------
              ListView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(16, safeTop + 8, 16, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2E7D32),
                          Color(0xFF66BB6A),
                          Color(0xFF26C6DA),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _circleButton(
                              Icons.arrow_back_ios_new_rounded,
                              () => Navigator.of(context).pop(),
                            ),
                            const Expanded(
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.palette_rounded,
                                        color: Colors.white, size: 22),
                                    SizedBox(width: 6),
                                    Text('Craft Details',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                            _circleButton(
                              _liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              () => setState(() => _liked = !_liked),
                              iconColor: _liked
                                  ? const Color(0xFFFF5252)
                                  : Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(height: videoH), // video slot
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FadeSlide(
                          delay: 0,
                          child: _titleSection(title, category, description),
                        ),
                        const SizedBox(height: 24),
                        _FadeSlide(
                          delay: 150,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFA726),
                                      Color(0xFFFF7043)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF7043)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.handyman_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Required Materials',
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2D3436))),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2ECC71)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '${_checked.length}/${materials.length}',
                                  style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (materials.isNotEmpty)
                          _FadeSlide(
                            delay: 250,
                            child: _progressCard(progress),
                          ),
                        const SizedBox(height: 14),
                        if (materials.isEmpty)
                          _emptyMaterials()
                        else
                          ...List.generate(materials.length, (i) {
                            final color = _palette[i % _palette.length];
                            final checked = _checked.contains(i);
                            return _FadeSlide(
                              delay: 300 + i * 90,
                              child: _MaterialTile(
                                text: materials[i].toString(),
                                index: i,
                                color: color,
                                checked: checked,
                                onTap: () => setState(() {
                                  checked
                                      ? _checked.remove(i)
                                      : _checked.add(i);
                                }),
                              ),
                            );
                          }),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: (materials.isNotEmpty &&
                                  _checked.length == materials.length)
                              ? _readyBanner()
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ---------- Floating / mini video player ----------
              ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (context, offset, _) {
                  final t = (offset / _dockEnd).clamp(0.0, 1.0);
                  final hidden = _miniClosed && t >= 1;

                  final left = _lerp(16, miniLeft, t);
                  final top = hidden
                      ? screenH + 50
                      : _lerp(slotTop - offset, miniTop, t);
                  final w = _lerp(videoW, miniW, t);
                  final h = _lerp(videoH, miniH, t);
                  final radius = BorderRadius.circular(_lerp(24, 16, t));

                  return Positioned(
                    left: left,
                    top: top,
                    width: w,
                    height: h,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: _lerp(0.25, 0.4, t)),
                            blurRadius: _lerp(20, 24, t),
                            offset: Offset(0, _lerp(10, 8, t)),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: player,
                      ),
                    ),
                  );
                },
              ),

              // ---------- Mini player buttons ----------
              ValueListenableBuilder<double>(
                valueListenable: _offset,
                builder: (context, offset, _) {
                  final t = (offset / _dockEnd).clamp(0.0, 1.0);
                  if (t < 0.98 || _miniClosed) return const SizedBox.shrink();

                  return Positioned(
                    left: miniLeft + miniW - 68,
                    top: miniTop + 6,
                    child: Row(
                      children: [
                        _miniButton(Icons.open_in_full_rounded, _expandMini),
                        const SizedBox(width: 6),
                        _miniButton(Icons.close_rounded, _closeMini),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Helper widgets ----------
  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap,
      {Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(icon, key: ValueKey(icon), color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _titleSection(String title, String category, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF66BB6A).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_rounded,
                      size: 14, color: Color(0xFF5C6BC0)),
                  const SizedBox(width: 6),
                  Text(category,
                      style: const TextStyle(
                          color: Color(0xFF5C6BC0),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          if (category.isNotEmpty) const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: Color(0xFF2D3436))),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description,
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: Colors.grey[700])),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _infoChip(Icons.play_circle_fill_rounded, 'Video guide',
                  const Color(0xFFEC407A)),
              const SizedBox(width: 8),
              _infoChip(Icons.child_care_rounded, 'Kid friendly',
                  const Color(0xFF26A69A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _progressCard(double progress) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 10,
          backgroundColor: Colors.white,
          color: const Color(0xFF2ECC71),
        ),
      ),
    );
  }

  Widget _emptyMaterials() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('No materials listed',
              style: TextStyle(color: Colors.grey[600], fontSize: 15)),
        ],
      ),
    );
  }

  Widget _readyBanner() {
    return Container(
      key: const ValueKey('ready'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2ECC71), Color(0xFF26C6DA)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ECC71).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_rounded, color: Colors.white, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have everything! Time to start crafting!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== MATERIAL TILE =====================
class _MaterialTile extends StatelessWidget {
  final String text;
  final int index;
  final Color color;
  final bool checked;
  final VoidCallback onTap;

  const _MaterialTile({
    required this.text,
    required this.index,
    required this.color,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: checked ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: checked ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: checked ? Colors.grey : const Color(0xFF2D3436),
                  decoration: checked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
                child: Text(text),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                checked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(checked),
                color: checked ? color : Colors.grey[400],
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== FADE + SLIDE HELPER =====================
class _FadeSlide extends StatelessWidget {
  final Widget child;
  final int delay;

  const _FadeSlide({required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}