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

class MegaOverflowApp extends StatelessWidget {
  const MegaOverflowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0A0A0A)),
    home: const MainScreen(),
  );
}

class MainScreen extends StatefulWidget { const MainScreen({super.key}); @override State<MainScreen> createState() => _MainScreenState(); }

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int currentView = 0;
  final player = AudioPlayer();
  bool isPlaying = false, isLoading = false;
  String title = "Mega Overflow Radio", artist = "Word, Worship and Wealth", cover = "";
  List history = [];
  late AnimationController vinyl;
  BannerAd? ad; bool adLoaded = false;

  final tabNames = ['Radio','Recently Played','Schedule','Sermons','E-Books','Audio Bible','Audiobooks','Chat','Partners','Volunteer','Testimony','About'];
  final icons = [Icons.radio, Icons.history, Icons.calendar_month, Icons.mic, Icons.menu_book, Icons.headphones, Icons.album, Icons.chat_bubble, Icons.handshake, Icons.groups, Icons.favorite, Icons.info];

  final events = [
    {'t':'Morning Overflow','d':'Mon-Fri','time':'5AM-7AM','h':'Pastor Chris Praiz'},
    {'t':'Worship Encounter','d':'Mon-Fri','time':'12PM-1PM','h':'Min. Damitha'},
    {'t':'Wealth Wisdom','d':'Wed & Fri','time':'7PM-8:30PM','h':'Pastor Chris'},
    {'t':'Sunday Prophetic','d':'Sunday','time':'8AM-11:30AM','h':'Pastor Chris Praiz'},
  ];

  @override
  void initState() {
    super.initState();
    vinyl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(); vinyl.stop();
    _fetch(); Timer.periodic(const Duration(seconds: 20), (_) => _fetch());
    ad = BannerAd(adUnitId: 'ca-app-pub-3940256099942544/6300978111', size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_){ setState(()=> adLoaded = true); }))..load();
  }

  Future<void> _fetch() async {
    try {
      final r = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/'));
      if (r.statusCode == 200) { final j = json.decode(r.body); setState((){ title = j['track']??j['title']??title; artist = j['artist']??artist; cover = j['thumb']??cover; }); }
      final h = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/'));
      if (h.statusCode == 200) setState(()=> history = json.decode(h.body));
    } catch(_){}
  }

  Future<void> toggle() async {
    if (isPlaying) { await player.pause(); setState(()=> isPlaying=false); vinyl.stop(); return; }
    setState(()=> isLoading=true);
    for (var u in ['https://stream.radiojar.com/kks1y4wm7s8uv','https://stream.radiojar.com/kks1y4wm7s8uv.mp3']) {
      try { await player.setAudioSource(AudioSource.uri(Uri.parse(u))); await player.play(); setState((){ isPlaying=true; isLoading=false; }); vinyl.repeat(); return; } catch(_){ continue; }
    }
    setState(()=> isLoading=false);
  }

  @override
  void dispose(){ player.dispose(); vinyl.dispose(); ad?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(backgroundColor: const Color(0xFF111111), child: Column(children: [
        Container(height: 120, width: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])), child: const SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Text('MEGA OVERFLOW\nWord • Worship • Wealth', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))),
        Expanded(child: ListView.builder(itemCount: tabNames.length, itemBuilder: (c,i)=> ListTile(leading: Icon(icons[i], color: currentView==i? Colors.orange: Colors.purpleAccent, size: 20), title: Text(tabNames[i], style: TextStyle(fontSize: 12, color: currentView==i? Colors.white: Colors.white70)), selected: currentView==i, onTap: (){ setState(()=> currentView=i); Navigator.pop(context); })))
      ])),
      appBar: AppBar(title: Text(tabNames[currentView], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF111111)),
      body: Column(children: [
        Expanded(child: IndexedStack(index: currentView, children: [_radio(), _history(), _schedule(), _sermons(), _ebooks(), _bible(), _audiobooks(), _chat(), _partners(), _volunteer(), _testimony(), _about()])),
        if(adLoaded && ad!=null) SizedBox(height: ad!.size.height.toDouble(), child: AdWidget(ad: ad!)),
        Container(height: 60, color: const Color(0xFF121212), padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Expanded(child: Text(title, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))), IconButton(onPressed: toggle, icon: Icon(isPlaying? Icons.pause_circle_filled: Icons.play_circle_filled, color: Colors.deepPurple, size: 36))]))
      ]),
    );
  }

  Widget _radio()=> SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    const SizedBox(height: 20),
    RotationTransition(turns: vinyl, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF141414), border: Border.all(color: Colors.black, width: 8)), child: Center(child: ClipOval(child: cover.isNotEmpty? Image.network(cover, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(width:100,height:100,color: Colors.orange)) : Container(width:100,height:100,color: Colors.orange, child: const Icon(Icons.mic)))))),
    const SizedBox(height: 20), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center), Text(artist, style: const TextStyle(color: Colors.purpleAccent)), const SizedBox(height: 20),
    isLoading? const CircularProgressIndicator(): ElevatedButton.icon(onPressed: toggle, icon: Icon(isPlaying? Icons.pause: Icons.play_arrow), label: Text(isPlaying? 'Pause': 'LISTEN LIVE'), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14))),
  ]));

  Widget _history()=> history.isEmpty? const Center(child: Text('No history yet')): ListView.builder(padding: const EdgeInsets.all(8), itemCount: history.length, itemBuilder: (_,i){ final t=history[i]; return Card(color: const Color(0xFF141414), child: ListTile(title: Text(t['track']??'', maxLines:1, style: const TextStyle(fontSize: 12)), subtitle: Text(t['artist']??'', style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)), leading: Image.network(t['thumb']??'', width: 50, errorBuilder: (_,__,___)=> Container(width:50,height:50,color: Colors.purple)))); });

  Widget _schedule()=> ListView.builder(padding: const EdgeInsets.all(10), itemCount: events.length, itemBuilder: (_,i){ final e=events[i]; return Card(color: const Color(0xFF141414), child: ListTile(title: Text(e['t']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text('${e['d']} • ${e['time']}'))); });

  Widget _sermons()=> ListView.builder(padding: const EdgeInsets.all(10), itemCount: 3, itemBuilder: (_,i)=> const Card(color: Color(0xFF141414), child: ListTile(leading: Icon(Icons.mic, color: Colors.deepPurple), title: Text('Overflow Anointing', style: TextStyle(fontSize: 12)), subtitle: Text('Pastor Chris • 45:23', style: TextStyle(fontSize: 10)))));

  Widget _ebooks()=> GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7), itemCount: 4, itemBuilder: (_,i)=> Card(color: const Color(0xFF141414), child: Column(children: [Expanded(child: Container(color: Colors.orange, child: const Icon(Icons.menu_book))), const Padding(padding: EdgeInsets.all(8), child: Text('Overflow Principles', style: TextStyle(fontSize: 11)))])));

  Widget _bible()=> ListView.builder(padding: const EdgeInsets.all(10), itemCount: 10, itemBuilder: (_,i){ final b=['Genesis','Exodus','Psalms','Matthew','John','Romans','Ephesians','Philippians','Hebrews','Revelation']; return Card(color: const Color(0xFF141414), child: ListTile(title: Text(b[i]), leading: Text('${i+1}', style: const TextStyle(color: Colors.orange)), trailing: const Icon(Icons.headphones, size: 18))); });

  Widget _audiobooks()=> ListView.builder(padding: const EdgeInsets.all(10), itemCount: 3, itemBuilder: (_,i)=> Card(color: const Color(0xFF141414), child: ListTile(title: const Text('Purpose Driven Life', style: TextStyle(fontSize: 12)), leading: Container(width:50,height:50,color: Colors.purple), trailing: ElevatedButton(onPressed: toggle, child: const Text('Play')))));

  Widget _chat()=> Padding(padding: const EdgeInsets.all(12), child: Column(children: [
    Expanded(child: ListView(children: const [Card(color: Color(0xFF141414), child: Padding(padding: EdgeInsets.all(12), child: Text('🙏 Welcome to Voice Altar - Share your prayer request', style: TextStyle(fontSize: 12)))), Card(color: Color(0xFF141414), child: Padding(padding: EdgeInsets.all(12), child: Text('Pastor Chris: We are praying with you! Overflow is yours!', style: TextStyle(fontSize: 12, color: Colors.purpleAccent))))])),
    TextField(decoration: InputDecoration(hintText: 'Type prayer...', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: const Icon(Icons.send, color: Colors.deepPurple)))
  ]));

  Widget _partners()=> SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    const Icon(Icons.handshake, size: 50, color: Colors.orange), const Text('Partner With Us', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    const SizedBox(height: 10),...['₦5,000 - Bronze','₦20,000 - Silver','₦100,000 - Gold'].map((e)=> Card(color: const Color(0xFF141414), child: ListTile(title: Text(e, style: const TextStyle(fontSize: 12))))),
    const SizedBox(height: 10), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final u=Uri.parse('https://paystack.com/pay/megaoverflow'); if(await canLaunchUrl(u)) await launchUrl(u); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple), child: const Text('Donate Now')))
  ]));

  Widget _volunteer()=> Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    const Text('Volunteer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 10),
    TextField(decoration: _dec('Full Name')), const SizedBox(height: 10), TextField(decoration: _dec('Phone')), const SizedBox(height: 20),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple), child: const Text('Submit')))
  ]));

  Widget _testimony()=> Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    const Text('Share Testimony', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 10),
    TextField(decoration: _dec('Name')), const SizedBox(height: 10), TextField(decoration: _dec('Testimony'), maxLines: 4), const SizedBox(height: 10),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple), child: const Text('Send')))
  ]));

  Widget _about()=> const Padding(padding: EdgeInsets.all(16), child: Text('Mega Overflow Radio is a 24/7 Gospel station spreading Word, Worship and Wealth worldwide.\n\nBased in Akwa Ibom, Nigeria.\n\nEmail: gcmega1@gmail.com', style: TextStyle(color: Colors.white70)));

  InputDecoration _dec(String l)=> InputDecoration(labelText: l, filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));
}
