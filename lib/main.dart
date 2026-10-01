import 'dart:async';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.megaoverflow.radio',
      androidNotificationChannelName: 'Mega Overflow',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('Background init failed: $e');
  }
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
  runApp(const MegaOverflowApp());
}

class MegaOverflowApp extends StatefulWidget {
  const MegaOverflowApp({super.key});
  @override
  State<MegaOverflowApp> createState() => _MegaOverflowAppState();
}

class _MegaOverflowAppState extends State<MegaOverflowApp> {
  bool isDark = true;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDark? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0A)),
      home: MainScreen(onTheme: () => setState(() => isDark =!isDark), isDark: isDark),
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback onTheme;
  final bool isDark;
  const MainScreen({super.key, required this.onTheme, required this.isDark});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int currentView = 0;
  final AudioPlayer player = AudioPlayer();
  final AudioPlayer bookPlayer = AudioPlayer();
  bool isPlaying = false;
  bool isLoading = false;
  String? activeBook;
  double volume = 1.0;
  bool isMuted = false;
  String title = "MEGA OVERFLOW RADIO";
  String artist = "Word, Worship and Wealth";
  List<Map<String, dynamic>> history = [];
  late AnimationController vinyl;
  BannerAd? bannerAd;
  bool isAdLoaded = false;
  Timer? metaTimer;
  Timer? sleepTimer;
  int sleepMin = 0;

  final chatCtrl = TextEditingController();
  final bibleSearchCtrl = TextEditingController();
  final volName = TextEditingController();
  final volPhone = TextEditingController();
  final testName = TextEditingController();
  final testMsg = TextEditingController();
  List<Map<String, String>> chatMsgs = [{'user': 'Pastor Chris', 'msg': 'Welcome! Share your prayer.'}];
  String bibleFilter = '';

  final List<String> tabNames = ['Radio','History','Schedule','Sermons','E-Books','Audio Bible','Audiobooks','Chat','Partner','Volunteer','Testimony','About'];
  final List<IconData> tabIcons = [Icons.radio,Icons.history,Icons.calendar_month,Icons.mic,Icons.menu_book,Icons.headphones,Icons.album,Icons.chat_bubble,Icons.handshake,Icons.groups,Icons.favorite,Icons.info];
  final List<String> bibleBooks = ["Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark","Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John","Jude","Revelation"];
  List<String> get filteredBible => bibleBooks.where((b) => b.toLowerCase().contains(bibleFilter.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    vinyl = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _initSession();
    fetchMeta();
    metaTimer = Timer.periodic(const Duration(seconds: 20), (_) => fetchMeta());
    _loadAd();
  }

  Future<void> _initSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(avAudioSessionCategory: AVAudioSessionCategory.playback, avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth, androidAudioAttributes: AndroidAudioAttributes(contentType: AndroidAudioContentType.music, usage: AndroidAudioUsage.media)));
    } catch (_) {}
  }

  void _loadAd() {
    try {
      bannerAd = BannerAd(adUnitId: 'ca-app-pub-3940256099942544/6300978111', size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_) => setState(() => isAdLoaded = true), onAdFailedToLoad: (ad, _) { ad.dispose(); setState(() => isAdLoaded = false); }))..load();
    } catch (_) {}
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/'));
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        if (mounted && d is Map) setState(() { title = d['track']?? d['title']?? title; artist = d['artist']?? artist; });
      }
      final his = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/'));
      if (his.statusCode == 200 && mounted) {
        final decoded = json.decode(his.body);
        if (decoded is List) history = decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
  }

  Future<void> togglePlay() async {
    if (isPlaying) { await player.pause(); setState(() => isPlaying = false); vinyl.stop(); return; }
    setState(() => isLoading = true);
    try {
      await player.setAudioSource(AudioSource.uri(Uri.parse('https://stream.radiojar.com/kks1y4wm7s8uv'), tag: MediaItem(id: 'live', title: title, artist: artist)));
      await player.setVolume(isMuted? 0 : volume);
      await player.play();
      setState(() { isPlaying = true; isLoading = false; });
      vinyl.repeat();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stream error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> toggleMute() async { setState(() => isMuted =!isMuted); await player.setVolume(isMuted? 0 : volume); await bookPlayer.setVolume(isMuted? 0 : volume); }
  Future<void> setVolume(double v) async { setState(() { volume = v; isMuted = v == 0; }); await player.setVolume(v); await bookPlayer.setVolume(v); }
  Future<void> playBook(String name) async {
    if (activeBook == name) { await bookPlayer.stop(); setState(() => activeBook = null); return; }
    await bookPlayer.setAudioSource(AudioSource.uri(Uri.parse('https://stream.radiojar.com/kks1y4wm7s8uv'), tag: MediaItem(id: name, title: name, artist: 'Mega Overflow')));
    await bookPlayer.setVolume(isMuted? 0 : volume);
    await bookPlayer.play();
    setState(() => activeBook = name);
  }

  // SAFE LOGO - NEVER CRASHES
  Widget safeLogo(double w, double h) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/icon/app_icon.png', width: w, height: h, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset('assets/icon/logo.png', width: w, height: h, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.radio, color: Colors.white, size: 40))),
      ),
    );
  }

  @override
  void dispose() { metaTimer?.cancel(); sleepTimer?.cancel(); player.dispose(); bookPlayer.dispose(); vinyl.dispose(); bannerAd?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(backgroundColor: const Color(0xFF111111), child: Column(children: [
        Container(height: 180, width: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])), child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [safeLogo(70, 70), const SizedBox(height: 8), const Text('MEGA OVERFLOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))]))),
        Expanded(child: ListView.builder(padding: EdgeInsets.zero, itemCount: tabNames.length, itemBuilder: (c, i) => ListTile(leading: Icon(tabIcons[i], color: currentView == i? Colors.orange : Colors.purpleAccent, size: 20), title: Text(tabNames[i], style: const TextStyle(fontSize: 12)), selected: currentView == i, onTap: () { setState(() => currentView = i); Navigator.pop(context); }))),
      ])),
      appBar: AppBar(backgroundColor: const Color(0xFF111111), title: Text(tabNames[currentView]), actions: [
        IconButton(icon: Icon(isMuted? Icons.volume_off : Icons.volume_up), onPressed: toggleMute),
        Container(margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(sleepMin > 0? '${sleepMin}m' : 'LIVE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
      ]),
      body: Column(children: [
        Expanded(child: IndexedStack(index: currentView, children: [
          // RADIO - SIMPLE AND SAFE
          ListView(padding: const EdgeInsets.all(20), children: [
            Center(child: RotationTransition(turns: vinyl, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 8)), child: ClipOval(child: safeLogo(220, 220))))),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10)), child: Row(children: [IconButton(icon: Icon(isMuted? Icons.volume_off : Icons.volume_down), onPressed: toggleMute), Expanded(child: Slider(value: volume, min: 0, max: 1, onChanged: setVolume)), const Icon(Icons.bluetooth, color: Colors.cyan)])),
            const SizedBox(height: 15),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(artist, textAlign: TextAlign.center, style: const TextStyle(color: Colors.purpleAccent)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isLoading? null : togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 15)), icon: isLoading? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(isPlaying? Icons.pause : Icons.play_arrow), label: Text(isPlaying? 'Pause' : 'Listen Live'))),
          ]),
          ListView.builder(padding: const EdgeInsets.all(12), itemCount: history.length, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: safeLogo(45, 45), title: Text(history[i]['track']?? 'Track', style: const TextStyle(fontSize: 12))))),
          const Center(child: Text('Schedule: Mon-Fri 5AM Morning Overflow')),
          const Center(child: Text('Sermons coming soon')),
          const Center(child: Text('E-Books coming soon')),
          Column(children: [Padding(padding: const EdgeInsets.all(12), child: TextField(controller: bibleSearchCtrl, onChanged: (v) => setState(() => bibleFilter = v), decoration: InputDecoration(hintText: 'Search Bible...', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))), Expanded(child: ListView.builder(itemCount: filteredBible.length, itemBuilder: (_, i) => ListTile(title: Text(filteredBible[i]), onTap: () => playBook(filteredBible[i]))))]),
          ListView.builder(padding: const EdgeInsets.all(12), itemCount: 8, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: safeLogo(50, 50), title: Text('Kingdom Wealth Part ${i + 1}'), trailing: ElevatedButton(onPressed: () => playBook('Part ${i + 1}'), child: Text(activeBook == 'Part ${i + 1}'? 'Stop' : 'Play'))))),
          Column(children: [Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: chatMsgs.length, itemBuilder: (_, i) => Align(alignment: chatMsgs[i]['user'] == 'You'? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: chatMsgs[i]['user'] == 'You'? Colors.deepPurple : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10)), child: Text(chatMsgs[i]['msg']!))))), Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: chatCtrl, decoration: InputDecoration(hintText: 'Prayer...', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))), IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: () { if (chatCtrl.text.isEmpty) return; setState(() { chatMsgs.add({'user': 'You', 'msg': chatCtrl.text}); chatMsgs.add({'user': 'Pastor Chris', 'msg': 'Praying: ${chatCtrl.text} 🙏'}); }); chatCtrl.clear(); })]))]),
          ListView(padding: const EdgeInsets.all(16), children: [Center(child: safeLogo(70, 70)), Card(color: const Color(0xFF141414), child: ListTile(title: const Text('Bronze ₦5k'), onTap: () async { final uri = Uri.parse('https://paystack.com/pay/megaoverflow'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }))]),
          Center(child: TextField(controller: volName, decoration: const InputDecoration(labelText: 'Name'))),
          Center(child: TextField(controller: testMsg, decoration: const InputDecoration(labelText: 'Testimony'))),
          ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(12)), child: const Text('Mega Overflow Radio v1.0', style: TextStyle(color: Colors.white)))]),
        ])),
        if (isAdLoaded && bannerAd!= null) SizedBox(height: bannerAd!.size.height.toDouble(), child: AdWidget(ad: bannerAd!)),
        Container(height: 80, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))), child: Column(children: [Slider(value: volume, min: 0, max: 1, onChanged: setVolume), Row(children: [safeLogo(36, 36), const SizedBox(width: 8), Expanded(child: Text(title, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))), IconButton(icon: Icon(isMuted? Icons.volume_off : Icons.volume_up, size: 20), onPressed: toggleMute), isLoading? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(onPressed: togglePlay, icon: Icon(isPlaying? Icons.pause_circle_filled : Icons.play_circle_filled, size: 34, color: Colors.deepPurple))])])),
      ]),
    );
  }
}