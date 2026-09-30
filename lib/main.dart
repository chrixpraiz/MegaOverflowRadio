import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MegaOverflowApp());
}

const String STATION_ID = 'kks1y4wm7s8uv';
const String STREAM_URL = 'https://stream.radiojar.com/$STATION_ID';
const String META_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/now_playing/';
const String HISTORY_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/tracks/';

class MegaOverflowApp extends StatelessWidget {
  const MegaOverflowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MegaOverflow Radio',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0A)),
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

  // ALL DATA FROM App.tsx
  final List<Map<String, dynamic>> events = [
    {'title': 'Morning Overflow', 'day': 'Mon - Fri', 'time': '5:00 AM - 7:00 AM', 'host': 'Pastor Chris Praiz', 'desc': 'Start your day with power-packed Word and worship', 'image': 'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?q=80&w=800'},
    {'title': 'Worship Encounter', 'day': 'Mon - Fri', 'time': '12:00 PM - 1:00 PM', 'host': 'Min. Damitha', 'desc': 'Midday worship to lift your spirit', 'image': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=800'},
    {'title': 'Wealth Wisdom', 'day': 'Wed & Fri', 'time': '7:00 PM - 8:30 PM', 'host': 'Pastor Chris', 'desc': 'Kingdom principles for financial overflow', 'image': 'https://images.unsplash.com/photo-1553729459-efe14ef6055d?q=80&w=800'},
    {'title': 'Sunday Prophetic Service', 'day': 'Sundays', 'time': '8:00 AM - 11:30 AM', 'host': 'Pastor Chris Praiz', 'desc': 'Prophetic impartation and miracles', 'image': 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?q=80&w=800'},
  ];

  final sermons = [
    {'title': 'The Overflow Anointing', 'preacher': 'Pastor Chris Praiz', 'duration': '45:23', 'image': 'https://images.unsplash.com/photo-1504052434569-70ad5836ab65'},
    {'title': 'Wealth Transfer', 'preacher': 'Pastor Chris Praiz', 'duration': '38:12', 'image': 'https://images.unsplash.com/photo-1527529482837-4698179dc6ce'},
    {'title': 'Worship That Opens Heaven', 'preacher': 'Min. Damitha', 'duration': '52:10', 'image': 'https://images.unsplash.com/photo-1516450360452-9312abbf6f7e'},
  ];

  final ebooks = [
    {'title': 'Overflow Principles', 'author': 'Chris Praiz', 'cover': 'https://images.unsplash.com/photo-1544947950-fa07a98d237f'},
    {'title': 'Kingdom Wealth', 'author': 'Chris Praiz', 'cover': 'https://images.unsplash.com/photo-1512820790803-83ca734da794'},
  ];

  final bibleBooks = ['Genesis','Exodus','Psalms','Proverbs','Isaiah','Matthew','John','Romans','Ephesians','Revelation'];

  final audiobooks = [
    {'title': 'Purpose Driven Life', 'author': 'Rick Warren', 'cover': 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e'},
    {'title': 'The Anointing', 'author': 'Benny Hinn', 'cover': 'https://images.unsplash.com/photo-1512820790803-83ca734da794'},
  ];

  final List<String> streamUrls = [
    'https://stream.radiojar.com/kks1y4wm7s8uv',
    'https://stream.radiojar.com/kks1y4wm7s8uv.mp3',
    'https://stream.radiojar.com/kks1y4wm7s8uv.m3u',
  ];

  @override
  void initState() {
    super.initState();
    vinylController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    vinylController.stop();
    fetchMeta(); fetchHistory();
    metaTimer = Timer.periodic(const Duration(seconds: 20), (_) { fetchMeta(); fetchHistory(); });
    _loadAd();
  }

  void _loadAd() {
    bannerAd = BannerAd(adUnitId: 'ca-app-pub-3940256099942544/6300978111', size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_) => setState(() => isAdLoaded = true)))..load();
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse(META_URL));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() { title = data['track']?? data['title']?? title; artist = data['artist']?? artist; cover = data['thumb']?? cover; });
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
    if (isPlaying) { await player.pause(); setState(() => isPlaying = false); vinylController.stop(); return; }
    setState(() => isLoading = true);
    for (var url in streamUrls) {
      try {
        await player.setAudioSource(AudioSource.uri(Uri.parse(url)));
        await player.play();
        setState(() { isPlaying = true; isLoading = false; vinylController.repeat(); });
        return;
      } catch (_) { continue; }
    }
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream offline - check data')));
  }

  @override
  void dispose() { metaTimer?.cancel(); player.dispose(); vinylController.dispose(); bannerAd?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final views = [_radioView(), _historyView(), _scheduleView(), _sermonsView(), _ebooksView(), _bibleView(), _audiobooksView(), _chatView(), _partnersView(), _volunteerView(), _testimonyView(), _aboutView()];
    final tabNames = ['Radio','Recently Played','Schedule','Sermons & Preaching','E-Books & Library','Audio Bible','Audiobooks','Chat & Voice Altar','Partner With Us','Volunteer','Testimony','About Us'];
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: _drawer(tabNames),
      appBar: AppBar(backgroundColor: const Color(0xFF111111), title: Text(tabNames[currentView], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), actions: [Container(margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: const Center(child: Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))))]),
      body: Column(children: [Expanded(child: views[currentView]), if (isAdLoaded && bannerAd!= null) Container(height: bannerAd!.size.height.toDouble(), color: Colors.black, child: AdWidget(ad: bannerAd!)), _miniPlayer()]),
    );
  }

  Widget _drawer(List<String> names) {
    final icons = [Icons.radio, Icons.history, Icons.calendar_month, Icons.mic, Icons.menu_book, Icons.headphones, Icons.album, Icons.chat_bubble, Icons.handshake, Icons.groups, Icons.favorite, Icons.info];
    return Drawer(backgroundColor: const Color(0xFF111111), child: ListView(padding: EdgeInsets.zero, children: [DrawerHeader(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.mic, color: Colors.deepPurple, size: 40)), const SizedBox(height: 10), const Text('MEGA OVERFLOW', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)), const Text('Word • Worship • Wealth', style: TextStyle(color: Colors.white70, fontSize: 10))])),...List.generate(names.length, (i) => ListTile(leading: Icon(icons[i], color: currentView == i? Colors.orange : Colors.purpleAccent, size: 20), title: Text(names[i], style: TextStyle(color: currentView == i? Colors.white : Colors.white70, fontWeight: currentView == i? FontWeight.bold : FontWeight.normal, fontSize: 12)), selected: currentView == i, selectedTileColor: Colors.purple.withOpacity(0.2), onTap: () { setState(() => currentView = i); Navigator.pop(context); })))]));
  }

  Widget _radioView() {
    return Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A0A0A), Color(0xFF000000)])), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [const SizedBox(height: 10), RotationTransition(turns: vinylController, child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF141414), border: Border.all(color: const Color(0xFF0F0F0F), width: 8), boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 20)]), child: Center(child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 4)), child: ClipOval(child: cover.isNotEmpty? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.orange, child: const Icon(Icons.mic))) : Container(color: Colors.orange, child: const Icon(Icons.mic, color: Colors.white, size: 40))))))), const SizedBox(height: 25), Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Column(children: [Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: isPlaying? Colors.green : Colors.orange, shape: BoxShape.circle)), const SizedBox(width: 8), Text(isPlaying? 'ON AIR NOW' : 'READY TO STREAM', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('320 KBPS HD', style: TextStyle(fontSize: 9, color: Colors.orange)))]), const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center), const SizedBox(height: 4), Text(artist, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 18), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isLoading? null : togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), icon: isLoading? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isPlaying? Icons.pause : Icons.play_arrow), label: Text(isPlaying? 'Pause Radio' : 'Listen Live', style: const TextStyle(fontWeight: FontWeight.w900))))]))])));
  }

  Widget _historyView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: history.length, itemBuilder: (c, i) { final t = history[i]; return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(t['thumb']?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.purple))), title: Text(t['track']?? t['title']?? 'Track', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text(t['artist']?? 'Mega Overflow', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)), trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.orange), onPressed: togglePlay))); });

  Widget _scheduleView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: events.length, itemBuilder: (c, i) { final e = events[i]; return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Row(children: [ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)), child: Image.network(e['image'] as String, width: 90, height: 90, fit: BoxFit.cover)), Expanded(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e['day'] as String, style: const TextStyle(fontSize: 9, color: Colors.orange)), Text(e['title'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), Text(e['time'] as String, style: const TextStyle(fontSize: 10, color: Colors.white60)), Text('Host: ${e['host']}', style: const TextStyle(fontSize: 10, color: Colors.purpleAccent))])))])); });

  Widget _sermonsView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: sermons.length, itemBuilder: (c, i) { final s = sermons[i]; return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(s['image'] as String, width: 60, height: 60, fit: BoxFit.cover)), title: Text(s['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text('${s['preacher']} • ${s['duration']}', style: const TextStyle(fontSize: 10)), trailing: const Icon(Icons.play_arrow, color: Colors.deepPurple))); });

  Widget _ebooksView() => GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: ebooks.length, itemBuilder: (c, i) { final b = ebooks[i]; return Card(color: const Color(0xFF141414), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: Column(children: [Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: Image.network(b['cover'] as String, width: double.infinity, fit: BoxFit.cover))), Padding(padding: const EdgeInsets.all(8), child: Column(children: [Text(b['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center), Text(b['author'] as String, style: const TextStyle(fontSize: 9, color: Colors.purpleAccent))]))])); });

  Widget _bibleView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: bibleBooks.length, itemBuilder: (c, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)))), title: Text(bibleBooks[i], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.headphones, color: Colors.orange), onTap: () {})));

  Widget _audiobooksView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: audiobooks.length, itemBuilder: (c, i) { final b = audiobooks[i]; return Card(color: const Color(0xFF141414), child: ListTile(leading: Image.network(b['cover'] as String, width: 50, height: 50, fit: BoxFit.cover), title: Text(b['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text(b['author'] as String, style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)), trailing: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(60, 30)), child: const Text('Play', style: TextStyle(fontSize: 10, color: Colors.black))))); });

  Widget _chatView() => Padding(padding: const EdgeInsets.all(16), child: Column(children: [Expanded(child: ListView(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Text('🙏 Welcome to Voice Altar - Share your prayer request', style: TextStyle(fontSize: 12))), const SizedBox(height: 10), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12)), child: const Text('Pastor Chris: We are praying with you! Overflow is yours!', style: TextStyle(fontSize: 12, color: Colors.purpleAccent)))]), TextField(decoration: InputDecoration(hintText: 'Type prayer request...', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: () {})),)]));

  Widget _partnersView() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [const Icon(Icons.handshake, size: 60, color: Colors.orange), const SizedBox(height: 12), const Text('Partner With Mega Overflow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Support 24/7 gospel broadcast worldwide', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)), const SizedBox(height: 20), _partnerTier('Bronze', '₦5,000/month', Colors.brown), _partnerTier('Silver', '₦20,000/month', Colors.grey), _partnerTier('Gold', '₦100,000/month', Colors.amber), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri = Uri.parse('https://paystack.com/pay/megaoverflow'); if (await canLaunchUrl(uri)) await launchUrl(uri); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Become a Partner')))]));

  Widget _partnerTier(String name, String price, Color color) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Row(children: [Icon(Icons.star, color: color), const SizedBox(width: 10), Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text(price, style: TextStyle(color: color, fontWeight: FontWeight.bold))]));

  Widget _volunteerView() => Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Icon(Icons.groups, size: 60, color: Colors.deepPurple), const SizedBox(height: 12), const Text('Join Our Team', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 16), TextField(decoration: _inputDec('Full Name')), const SizedBox(height: 10), TextField(decoration: _inputDec('Phone / WhatsApp')), const SizedBox(height: 10), DropdownButtonFormField(items: const [DropdownMenuItem(value: 'Media', child: Text('Media')), DropdownMenuItem(value: 'Prayer', child: Text('Prayer Team')), DropdownMenuItem(value: 'Outreach', child: Text('Outreach'))], onChanged: (_) {}, decoration: _inputDec('Department'),), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Apply to Volunteer')))]));

  Widget _testimonyView() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [const Icon(Icons.favorite, size: 50, color: Colors.orange), const SizedBox(height: 12), const Text('Share Your Praise Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 16), TextField(decoration: _inputDec('Your Name')), const SizedBox(height: 10), TextField(decoration: _inputDec('Location')), const SizedBox(height: 10), TextField(decoration: _inputDec('Testimony'), maxLines: 5), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri = Uri.parse('mailto:gcmega1@gmail.com?subject=Testimony - Mega Overflow'); if (await canLaunchUrl(uri)) await launchUrl(uri); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Submit Testimony')))]));

  Widget _aboutView() => ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(16)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Our Divine Mandate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), SizedBox(height: 8), Text('Mega Overflow Radio is a premier 24/7 internet radio station dedicated to delivering transformative gospel broadcasts: Word, Worship, and Wealth encounters.', style: TextStyle(color: Colors.white, fontSize: 12))])), const SizedBox(height: 12), _aboutCard('Vision', 'To saturate the airwaves with the overflow of God\'s presence and power.'), _aboutCard('Mission', '24/7 Word, Worship, and Wealth to every nation.'), _aboutCard('Contact', 'Email: gcmega1@gmail.com\nPhone: +234 000 000 0000\nLocation: Akwa Ibom, Nigeria')]);

  Widget _aboutCard(String t, String d) => Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)), const SizedBox(height: 4), Text(d, style: const TextStyle(color: Colors.white70, fontSize: 12))])));

  InputDecoration _inputDec(String label) => InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

  Widget _miniPlayer() => Container(height: 68, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(6), child: cover.isNotEmpty? Image.network(cover, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.orange)) : Container(width: 44, height: 44, color: Colors.orange, child: const Icon(Icons.mic, size: 20))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.purpleAccent, fontSize: 9))])), IconButton(onPressed: togglePlay, icon: Icon(isPlaying? Icons.pause_circle_filled : Icons.play_circle_filled, size: 38, color: Colors.deepPurple))]));
}
