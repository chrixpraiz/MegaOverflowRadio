import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MegaOverflowApp());
}

const STATION_ID = 'kks1y4wm7s8uv';
const STREAM_URL = 'https://stream.radiojar.com/kks1y4wm7s8uv';
const META_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/now_playing/';
const HISTORY_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/tracks/';

class MegaOverflowApp extends StatelessWidget {
  const MegaOverflowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MegaOverflow Radio',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0A)),
      theme: ThemeData.dark(),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int currentView = 0;
  final player = AudioPlayer();
  bool isPlaying = false, isLoading = false;
  String title = 'Mega Overflow Radio';
  String artist = '24/7 Word, Worship and Wealth';
  String cover = '';
  List<dynamic> history = [];
  Timer? metaTimer;
  late AnimationController vinylController;
  BannerAd? bannerAd;
  bool isAdLoaded = false;

  // Schedule data from your App.tsx
  final events = [
    {'title': 'Morning Overflow', 'day': 'Mon - Fri', 'time': '5:00 AM - 7:00 AM', 'host': 'Pastor Chris Praiz', 'image': 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618'},
    {'title': 'Worship Encounter', 'day': 'Mon - Fri', 'time': '12:00 PM - 1:00 PM', 'host': 'Min. Damitha', 'image': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4'},
    {'title': 'Wealth Wisdom', 'day': 'Wed & Fri', 'time': '7:00 PM - 8:30 PM', 'host': 'Pastor Chris', 'image': 'https://images.unsplash.com/photo-1553729459-efe14ef6055d'},
    {'title': 'Sunday Prophetic Service', 'day': 'Sundays', 'time': '8:00 AM - 11:30 AM', 'host': 'Pastor Chris Praiz', 'image': 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4'},
  ];

  @override
  void initState() {
    super.initState();
    vinylController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    vinylController.stop();
    fetchMeta();
    fetchHistory();
    metaTimer = Timer.periodic(const Duration(seconds: 20), (_) { fetchMeta(); fetchHistory(); });
    loadAd();
  }

  void loadAd() {
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(onAdLoaded: (_) => setState(() => isAdLoaded = true)),
    )..load();
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse(META_URL));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          title = data['track']?? data['title']?? title;
          artist = data['artist']?? artist;
          cover = data['thumb']?? cover;
        });
      }
    } catch (_) {}
  }

  Future<void> fetchHistory() async {
    try {
      final res = await http.get(Uri.parse(HISTORY_URL));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) setState(() => history = data);
      }
    } catch (_) {}
  }

  Future<void> togglePlay() async {
    if (isPlaying) {
      await player.pause();
      setState(() => isPlaying = false);
      vinylController.stop();
      return;
    }
    setState(() => isLoading = true);
    try {
      await player.setAudioSource(AudioSource.uri(Uri.parse(STREAM_URL)));
      await player.play();
      setState(() { isPlaying = true; vinylController.repeat(); });
    } catch (e) {
      // fallback.mp3
      try {
        await player.setAudioSource(AudioSource.uri(Uri.parse('$STREAM_URL.mp3')));
        await player.play();
        setState(() { isPlaying = true; vinylController.repeat(); });
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stream error: $e2')));
      }
    }
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    metaTimer?.cancel();
    player.dispose();
    vinylController.dispose();
    bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      _radioView(),
      _historyView(),
      _scheduleView(),
      _simpleView('Sermons & Preaching', 'Firebase sermons coming soon', Icons.mic),
      _simpleView('E-Books & Library', 'Kingdom e-books library', Icons.book),
      _simpleView('Audio Bible', '66 Books Audio Drama', Icons.headphones),
      _simpleView('Audiobooks', 'Gospel Audiobook Library', Icons.album),
      _simpleView('Chat & Voice Altar', 'Live Voice Intercession', Icons.chat_bubble),
      _simpleView('Partner With Us', 'Support the broadcast', Icons.handshake),
      _simpleView('Volunteer', 'Join the team', Icons.groups),
      _testimonyView(),
      _aboutView(),
    ];

    return Scaffold(
      drawer: _drawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: const Text('MEGA OVERFLOW RADIO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        actions: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: const Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(children: [
        Expanded(child: views[currentView]),
        if (isAdLoaded && bannerAd!= null) Container(height: bannerAd!.size.height.toDouble(), color: Colors.black, child: AdWidget(ad: bannerAd!)),
        _miniPlayer(),
      ]),
    );
  }

  Widget _drawer() {
    final items = [
      {'icon': Icons.radio, 'label': 'Radio'},
      {'icon': Icons.history, 'label': 'Recently Played'},
      {'icon': Icons.calendar_month, 'label': 'Schedule'},
      {'icon': Icons.mic, 'label': 'Sermons & Preaching'},
      {'icon': Icons.book, 'label': 'E-Books & Library'},
      {'icon': Icons.headphones, 'label': 'Audio Bible'},
      {'icon': Icons.album, 'label': 'Audiobooks'},
      {'icon': Icons.chat, 'label': 'Chat & Voice Altar'},
      {'icon': Icons.handshake, 'label': 'Partner With Us'},
      {'icon': Icons.groups, 'label': 'Volunteer'},
      {'icon': Icons.favorite, 'label': 'Testimony'},
      {'icon': Icons.info, 'label': 'About Us'},
    ];
    return Drawer(
      backgroundColor: const Color(0xFF111111),
      child: ListView(
        children: [
          DrawerHeader(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])), child: Column(children: [Image.asset('assets/icon/app_icon.png', height: 60, errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 60, color: Colors.white)), const SizedBox(height: 10), const Text('MEGA OVERFLOW', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))]))),
         ...List.generate(items.length, (i) => ListTile(
            leading: Icon(items[i]['icon'] as IconData, color: currentView == i? Colors.orange : Colors.purpleAccent),
            title: Text(items[i]['label'] as String, style: TextStyle(color: currentView == i? Colors.white : Colors.white70, fontWeight: currentView == i? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            selected: currentView == i,
            selectedTileColor: Colors.purple.withOpacity(0.2),
            onTap: () { setState(() => currentView = i); Navigator.pop(context); },
          )),
        ],
      ),
    );
  }

  Widget _radioView() {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A0A0A), Color(0xFF000000)])),
      child: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 20),
          // Vinyl
          RotationTransition(
            turns: vinylController,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF141414), border: Border.all(color: const Color(0xFF0F0F0F), width: 8), boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 20)]),
              child: Center(child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 4)), child: ClipOval(child: cover.isNotEmpty? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/icon/app_icon.png', errorBuilder: (_, __, ___) => Container(color: Colors.orange))) : Image.asset('assets/icon/app_icon.png', errorBuilder: (_, __, ___) => Container(color: Colors.orange, child: const Icon(Icons.mic, color: Colors.white)))))),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
            child: Column(children: [
              Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: isPlaying? Colors.green : Colors.orange, shape: BoxShape.circle)), const SizedBox(width: 8), Text(isPlaying? 'ON AIR NOW' : 'READY TO STREAM', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('320 KBPS HD', style: TextStyle(fontSize: 10, color: Colors.orange)))]),
              const SizedBox(height: 15),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center, maxLines: 2),
              const SizedBox(height: 6),
              Text(artist, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: ElevatedButton.icon(onPressed: isLoading? null : togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: isLoading? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isPlaying? Icons.pause : Icons.play_arrow), label: Text(isPlaying? 'Pause Radio' : 'Listen Live', style: const TextStyle(fontWeight: FontWeight.w900)))),
                const SizedBox(width: 12),
                Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)), child: IconButton(onPressed: () => setState(() => currentView = 1), icon: const Icon(Icons.list, color: Colors.orange))),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _historyView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.isEmpty? 5 : history.length,
      itemBuilder: (c, i) {
        if (history.isEmpty) return const ListTile(title: Text('Loading history...'));
        final t = history[i];
        return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(t['thumb']?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.purple))), title: Text(t['track']?? t['title']?? 'Gospel Track', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text(t['artist']?? 'Mega Overflow', style: const TextStyle(color: Colors.purpleAccent, fontSize: 11)), trailing: Text(t['tm']!= null? DateTime.tryParse(t['tm'])?.toLocal().toString().substring(11, 16)?? '' : '', style: const TextStyle(fontSize: 10, color: Colors.white54))));
      },
    );
  }

  Widget _scheduleView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (c, i) {
        final e = events[i];
        return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Row(children: [ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)), child: Image.network(e['image'] as String, width: 100, height: 100, fit: BoxFit.cover)), Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(e['day'] as String, style: const TextStyle(fontSize: 9, color: Colors.purpleAccent)),), const SizedBox(width: 6), Text(e['time'] as String, style: const TextStyle(fontSize: 9, color: Colors.orange))]), const SizedBox(height: 6), Text(e['title'] as String, style: const TextStyle(fontWeight: FontWeight.w900)), Text('Host: ${e['host']}', style: const TextStyle(fontSize: 11, color: Colors.purpleAccent)), const SizedBox(height: 8), ElevatedButton(onPressed: togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: const Size(0, 30)), child: const Text('Listen', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)))])))]));
      },
    );
  }

  Widget _simpleView(String title, String desc, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 60, color: Colors.deepPurple), const SizedBox(height: 16), Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)))]));
  }

  Widget _testimonyView() {
    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Icon(Icons.favorite, size: 50, color: Colors.orange), const SizedBox(height: 12), const Text('Share Your Praise Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 20), TextField(decoration: InputDecoration(labelText: 'Your Name', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))), const SizedBox(height: 12), TextField(decoration: InputDecoration(labelText: 'Testimony', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), maxLines: 4), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri = Uri.parse('mailto:gcmega1@gmail.com?subject=Testimony'); if (await canLaunchUrl(uri)) await launchUrl(uri); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Submit Testimony')))]));
  }

  Widget _aboutView() {
    return ListView(padding: const EdgeInsets.all(20), children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Our Divine Mandate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 10), Text('Mega Overflow Radio is a premier 24/7 internet radio station dedicated to delivering transformative gospel broadcasts: Word, Worship, and Wealth encounters.', style: TextStyle(color: Colors.white70))]))]);
  }

  Widget _miniPlayer() {
    return Container(height: 70, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: cover.isNotEmpty? Image.network(cover, width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 45, height: 45, color: Colors.orange)) : Container(width: 45, height: 45, color: Colors.orange, child: const Icon(Icons.mic))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.purpleAccent, fontSize: 10))])), IconButton(onPressed: togglePlay, icon: Icon(isPlaying? Icons.pause_circle_filled : Icons.play_circle_filled, size: 40, color: Colors.deepPurple))]));
  }
}
