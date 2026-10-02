import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const String kStationId = 'kks1y4wm7s8uv';
const String kMetaUrl =
    'https://www.radiojar.com/api/stations/$kStationId/now_playing/';
const String kHistoryUrl =
    'https://www.radiojar.com/api/stations/$kStationId/tracks/';
const String kStreamUrl = 'https://stream.radiojar.com/$kStationId';
const String kBibleApi = 'https://bible-api.com/';

// AdMob – swap to real banner ID before publishing
const String kBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.megaoverflow.megaoverflowradio',
      androidNotificationChannelName: 'Mega Overflow Radio',
      androidNotificationOngoing: true,
    );
  } catch (e, st) {
    debugPrint('JustAudioBackground.init failed: $e\n$st');
  }

  try {
    await MobileAds.instance.initialize();
  } catch (e, st) {
    debugPrint('MobileAds.init failed: $e\n$st');
  }

  runApp(const MegaOverflowApp());
}

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------
class MegaOverflowApp extends StatelessWidget {
  const MegaOverflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mega Overflow Radio',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111111),
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  // ---- Tab state ----
  int currentView = 0;

  static const List<String> _tabNames = [
    'Radio',
    'Recently Played',
    'Schedule',
    'Written Bible',
    'Audio Bible',
    'Voice Altar',
    'Partner',
    'Volunteer',
    'Testimony',
    'About',
  ];

  static const List<IconData> _tabIcons = [
    Icons.radio,
    Icons.history,
    Icons.calendar_month,
    Icons.menu_book,
    Icons.headphones,
    Icons.chat_bubble,
    Icons.handshake,
    Icons.groups,
    Icons.favorite,
    Icons.info,
  ];

  // ---- Audio ----
  final AudioPlayer player = AudioPlayer();
  bool isPlaying = false;
  bool isLoading = false;
  double volume = 1.0;
  bool isMuted = false;
  String currentStreamUrl = '';
  StreamSubscription<PlayerState>? _playerStateSub;

  // ---- Metadata ----
  String title = 'Mega Overflow Radio';
  String artist = '24/7 Word, Worship and Wealth';
  String cover = '';
  String listeners = '0';
  List<Map<String, dynamic>> history = [];
  Timer? _metaTimer;

  // ---- Vinyl animation ----
  late AnimationController vinylController;

  // ---- Ads ----
  BannerAd? bannerAd;
  bool isAdLoaded = false;

  // ---- Text controllers ----
  final TextEditingController chatCtrl = TextEditingController();
  final TextEditingController volNameCtrl = TextEditingController();
  final TextEditingController volPhoneCtrl = TextEditingController();
  final TextEditingController testNameCtrl = TextEditingController();
  final TextEditingController testLocCtrl = TextEditingController();
  final TextEditingController testStoryCtrl = TextEditingController();
  final TextEditingController bibleSearchCtrl = TextEditingController();

  // ---- Bible ----
  String bibleText = 'Search for a verse, e.g. John 3:16 or Genesis 1:1';
  bool bibleLoading = false;
  final List<String> bibleBooks = const [
    'Genesis', 'Exodus', 'Leviticus', 'Psalms', 'Proverbs',
    'Isaiah', 'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', 'Ephesians', 'Philippians', 'Revelation',
  ];

  // ---- Chat ----
  final List<Map<String, String>> chatMessages = [
    {
      'user': 'Pastor Chris',
      'msg': 'We are praying with you! Overflow is yours! 🙏'
    },
  ];

  // ---- Audio Bible samples (replace with real URLs) ----
  final List<Map<String, String>> audioBible = const [
    {
      'book': 'Genesis 1',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'duration': '4:32',
    },
    {
      'book': 'Psalm 23',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      'duration': '2:15',
    },
    {
      'book': 'John 1',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      'duration': '5:12',
    },
    {
      'book': 'Romans 8',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      'duration': '3:45',
    },
  ];

  // ---- Events ----
  final List<Map<String, String>> events = const [
    {
      'title': 'Morning Overflow',
      'day': 'Mon - Fri',
      'time': '5AM - 7AM',
      'host': 'Pastor Chris Praiz',
    },
    {
      'title': 'Worship Encounter',
      'day': 'Mon - Fri',
      'time': '12PM - 1PM',
      'host': 'Min. Damitha',
    },
    {
      'title': 'Sunday Prophetic',
      'day': 'Sundays',
      'time': '8AM - 11:30AM',
      'host': 'Pastor Chris Praiz',
    },
  ];

  // =========================================================================
  // Lifecycle
  // =========================================================================
  @override
  void initState() {
    super.initState();
    vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _initAudioSession();
    _listenToPlayerState();
    fetchMeta();
    fetchHistory();
    _loadAd();

    _metaTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      fetchMeta();
      fetchHistory();
    });
  }

  @override
  void dispose() {
    _metaTimer?.cancel();
    _playerStateSub?.cancel();
    player.dispose();
    vinylController.dispose();
    bannerAd?.dispose();
    chatCtrl.dispose();
    volNameCtrl.dispose();
    volPhoneCtrl.dispose();
    testNameCtrl.dispose();
    testLocCtrl.dispose();
    testStoryCtrl.dispose();
    bibleSearchCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  // Init helpers
  // =========================================================================
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('AudioSession configure failed: $e\n$st');
    }
  }

  void _listenToPlayerState() {
    _playerStateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing &&
          state.processingState != ProcessingState.completed;
      if (playing != isPlaying) {
        setState(() => isPlaying = playing);
        if (playing) {
          vinylController.repeat();
        } else {
          vinylController.stop();
        }
      }
    }, onError: (e) => debugPrint('Player state error: $e'));
  }

  void _loadAd() {
    try {
      bannerAd = BannerAd(
        adUnitId: kBannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => isAdLoaded = true);
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint('Banner ad failed: $err');
            ad.dispose();
            if (mounted) setState(() => isAdLoaded = false);
          },
        ),
      )..load();
    } catch (e, st) {
      debugPrint('Banner ad init failed: $e\n$st');
    }
  }

  // =========================================================================
  // Metadata / history
  // =========================================================================
  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse(kMetaUrl));
      if (res.statusCode != 200) return;
      final dynamic decoded = json.decode(res.body);
      if (decoded is! Map) return;
      if (!mounted) return;
      setState(() {
        title = (decoded['track'] ?? decoded['title'] ?? title).toString();
        artist = (decoded['artist'] ?? artist).toString();
        cover = (decoded['thumb'] ?? cover).toString();
        listeners =
            (decoded['listeners'] ??
                    (decoded['now_playing'] is Map
                        ? decoded['now_playing']['listeners']
                        : null) ??
                    '0')
                .toString();
      });
    } catch (e) {
      debugPrint('fetchMeta failed: $e');
    }
  }

  Future<void> fetchHistory() async {
    try {
      final res = await http.get(Uri.parse(kHistoryUrl));
      if (res.statusCode != 200) return;
      final dynamic decoded = json.decode(res.body);
      if (decoded is! List) return;
      if (!mounted) return;
      setState(() {
        history = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      debugPrint('fetchHistory failed: $e');
    }
  }

  // =========================================================================
  // Bible
  // =========================================================================
  Future<void> fetchBible(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      bibleLoading = true;
      bibleText = 'Loading…';
    });

    try {
      final res = await http.get(
        Uri.parse('$kBibleApi${Uri.encodeComponent(q)}'),
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final dynamic decoded = json.decode(res.body);
        if (decoded is Map) {
          final ref = (decoded['reference'] ?? q).toString();
          final text = (decoded['text'] ?? 'No text').toString().trim();
          setState(() => bibleText = '$ref\n\n$text');
        } else {
          setState(() => bibleText = 'Invalid response.');
        }
      } else {
        setState(() => bibleText = 'Not found. Try e.g. John 3:16');
      }
    } catch (e) {
      debugPrint('fetchBible failed: $e');
      if (mounted) {
        setState(() => bibleText = 'Error: check your internet connection.');
      }
    } finally {
      if (mounted) setState(() => bibleLoading = false);
    }
  }

  // =========================================================================
  // Playback
  // =========================================================================
  Future<void> playUrl(String url, String trackTitle, String trackArtist) async {
    setState(() => isLoading = true);
    try {
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: url,
            title: trackTitle,
            artist: trackArtist,
            artUri: cover.isNotEmpty ? Uri.tryParse(cover) : null,
          ),
        ),
      );
      await player.setVolume(isMuted ? 0 : volume);
      await player.play();

      if (!mounted) return;
      setState(() {
        title = trackTitle;
        artist = trackArtist;
        currentStreamUrl = url;
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('playUrl failed: $e\n$st');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Play failed. Check your connection.', isError: true);
    }
  }

  Future<void> togglePlay() async {
    // If currently playing → pause
    if (isPlaying) {
      await player.pause();
      return;
    }

    // If paused with an existing source → resume
    if (player.audioSource != null && currentStreamUrl.isNotEmpty) {
      try {
        await player.play();
        return;
      } catch (_) {
        // Fall through to fresh load
      }
    }

    // Fresh load of the live stream
    setState(() => isLoading = true);
    try {
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(kStreamUrl),
          tag: MediaItem(
            id: 'live',
            title: 'Mega Overflow Radio',
            artist: 'LIVE • $listeners listening',
          ),
        ),
      );
      await player.setVolume(isMuted ? 0 : volume);
      await player.play();
      if (!mounted) return;
      setState(() {
        currentStreamUrl = kStreamUrl;
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Live stream failed: $e\n$st');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Stream offline. Try again.', isError: true);
    }
  }

  Future<void> toggleMute() async {
    final newMuted = !isMuted;
    setState(() => isMuted = newMuted);
    try {
      await player.setVolume(newMuted ? 0 : volume);
    } catch (_) {}
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    setState(() {
      volume = clamped;
      isMuted = clamped == 0;
    });
    try {
      await player.setVolume(clamped);
    } catch (_) {}
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // =========================================================================
  // Shared widgets
  // =========================================================================
  Widget _logo(double w, double h, {double radius = 12}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/icon/logo.png',
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: w,
            height: h,
            color: Colors.deepPurple,
            child: const Icon(Icons.radio, color: Colors.white),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

  // =========================================================================
  // Build
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final views = <Widget>[
      _radioView(),
      _historyView(),
      _scheduleView(),
      _writtenBibleView(),
      _audioBibleView(),
      _chatView(),
      _partnersView(),
      _volunteerView(),
      _testimonyView(),
      _aboutView(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: currentView,
              children: views,
            ),
          ),
          if (isAdLoaded && bannerAd != null)
            SizedBox(
              height: bannerAd!.size.height.toDouble(),
              width: bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: bannerAd!),
            ),
          _miniPlayer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF111111),
      title: Text(
        _tabNames[currentView],
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      ),
      actions: [
        IconButton(
          icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
          onPressed: toggleMute,
        ),
        Container(
          margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              'LIVE $listeners',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF111111),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _logo(60, 60),
                const SizedBox(height: 10),
                const Text(
                  'MEGA OVERFLOW',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Word • Worship • Wealth • $listeners Online',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          ...List.generate(_tabNames.length, (i) {
            final selected = currentView == i;
            return ListTile(
              leading: Icon(
                _tabIcons[i],
                color: selected ? Colors.orange : Colors.purpleAccent,
                size: 20,
              ),
              title: Text(
                _tabNames[i],
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              selected: selected,
              onTap: () {
                setState(() => currentView = i);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // Views
  // =========================================================================
  Widget _radioView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RotationTransition(
            turns: vinylController,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF141414),
                border: Border.all(color: Colors.white10, width: 8),
              ),
              child: Center(
                child: ClipOval(
                  child: cover.isNotEmpty
                      ? Image.network(
                          cover,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _logo(110, 110, radius: 100),
                        )
                      : _logo(110, 110, radius: 100),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isMuted ? Icons.volume_off : Icons.volume_down),
                  onPressed: toggleMute,
                ),
                Expanded(
                  child: Slider(
                    value: volume,
                    min: 0,
                    max: 1,
                    activeColor: Colors.deepPurple,
                    onChanged: setVolume,
                  ),
                ),
                Text('${(volume * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 8),
                const Icon(Icons.bluetooth, color: Colors.cyan, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isPlaying ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPlaying
                          ? 'ON AIR • $listeners LISTENERS'
                          : 'READY TO STREAM',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '320 KBPS HD',
                      style: TextStyle(fontSize: 9, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  artist,
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : togglePlay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      isPlaying
                          ? 'Pause Radio'
                          : 'Listen Live ($listeners Online)',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyView() {
    if (history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: history.length,
      itemBuilder: (_, i) {
        final t = history[i];
        return Card(
          color: const Color(0xFF141414),
          child: ListTile(
            leading: _logo(48, 48),
            title: Text(
              (t['track'] ?? t['title'] ?? 'Track').toString(),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              (t['artist'] ?? '').toString(),
              style: const TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle, color: Colors.orange),
              onPressed: () => togglePlay(),
            ),
          ),
        );
      },
    );
  }

  Widget _scheduleView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final e = events[i];
        return Card(
          color: const Color(0xFF141414),
          child: ListTile(
            leading: _logo(50, 50),
            title: Text(
              e['title'] ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${e['day']} • ${e['time']}\n${e['host']}',
              style: const TextStyle(fontSize: 11),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _writtenBibleView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: bibleSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search John 3:16, Genesis 1…',
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: fetchBible,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.orange),
                onPressed: () => fetchBible(bibleSearchCtrl.text),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: bibleBooks
                .map(
                  (b) => ActionChip(
                    label: Text(b, style: const TextStyle(fontSize: 10)),
                    backgroundColor: const Color(0xFF1E1E1E),
                    onPressed: () => fetchBible(b),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: bibleLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Text(
                        bibleText,
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audioBibleView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: audioBible.length,
      itemBuilder: (_, i) {
        final b = audioBible[i];
        return Card(
          color: const Color(0xFF141414),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.headphones, color: Colors.orange),
            ),
            title: Text(
              b['book'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Duration: ${b['duration']}',
              style: const TextStyle(fontSize: 10),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.play_circle,
                color: Colors.deepPurple,
                size: 32,
              ),
              onPressed: () => playUrl(
                b['url']!,
                b['book']!,
                'Audio Bible KJV',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chatView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: chatMessages.length,
              itemBuilder: (_, i) {
                final m = chatMessages[i];
                final isMe = m['user'] == 'You';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.deepPurple.withValues(alpha: 0.3)
                        : const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['user'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(m['msg'] ?? '', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatCtrl,
                  decoration: InputDecoration(
                    hintText: 'Share prayer request…',
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.deepPurple),
                onPressed: () {
                  final text = chatCtrl.text.trim();
                  if (text.isEmpty) return;
                  setState(() {
                    chatMessages.add({'user': 'You', 'msg': text});
                  });
                  chatCtrl.clear();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _partnersView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: _logo(80, 80)),
        const SizedBox(height: 12),
        const Text(
          'Partner With Us',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        ...['Bronze ₦5k', 'Silver ₦20k', 'Gold ₦100k'].map(
          (tier) => Card(
            color: const Color(0xFF141414),
            child: ListTile(
              title: Text(tier),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () async {
                final uri =
                    Uri.parse('https://paystack.com/pay/megaoverflow');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _volunteerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.groups, size: 60, color: Colors.deepPurple),
          const Text(
            'Join Our Volunteer Team',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: volNameCtrl,
            decoration: _inputDecoration('Full Name *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: volPhoneCtrl,
            decoration: _inputDecoration('Phone / WhatsApp *'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (volNameCtrl.text.isEmpty || volPhoneCtrl.text.isEmpty) {
                  _showSnack('Fill all fields', isError: true);
                  return;
                }
                final uri = Uri.parse(
                  'mailto:gcmega1@gmail.com'
                  '?subject=${Uri.encodeComponent('Volunteer - ${volNameCtrl.text}')}'
                  '&body=${Uri.encodeComponent('Name: ${volNameCtrl.text}\nPhone: ${volPhoneCtrl.text}')}',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
                _showSnack('Application sent!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Apply to Volunteer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testimonyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.favorite, size: 50, color: Colors.orange),
          const Text(
            'Share Your Praise Report',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: testNameCtrl,
            decoration: _inputDecoration('Your Name *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: testLocCtrl,
            decoration: _inputDecoration('Location'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: testStoryCtrl,
            decoration: _inputDecoration('Your Testimony *'),
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (testNameCtrl.text.isEmpty || testStoryCtrl.text.isEmpty) {
                  _showSnack('Please fill in your testimony', isError: true);
                  return;
                }
                final uri = Uri.parse(
                  'mailto:gcmega1@gmail.com'
                  '?subject=${Uri.encodeComponent('Testimony - ${testNameCtrl.text}')}'
                  '&body=${Uri.encodeComponent('Name: ${testNameCtrl.text}\nLocation: ${testLocCtrl.text}\n\n${testStoryCtrl.text}')}',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
                _showSnack('Testimony submitted! God bless!');
                testNameCtrl.clear();
                testLocCtrl.clear();
                testStoryCtrl.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Submit Testimony'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Mega Overflow Radio\n\n'
            'Word • Worship • Wealth\n\n'
            'Background play • Bluetooth controls • Audio Bible • Voice Altar',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _miniPlayer() {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 22,
            child: Slider(
              value: volume,
              min: 0,
              max: 1,
              activeColor: Colors.deepPurple,
              inactiveColor: Colors.white12,
              onChanged: setVolume,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _logo(36, 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.purpleAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    size: 20,
                  ),
                  onPressed: toggleMute,
                ),
                isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: togglePlay,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 38,
                          color: Colors.deepPurple,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}