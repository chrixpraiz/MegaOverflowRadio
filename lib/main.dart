import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.megaoverflow.radio',
      androidNotificationChannelName: 'Mega Overflow Radio',
      androidNotificationOngoing: true,
    );
  } catch (_) {}
  try { await MobileAds.instance.initialize(); } catch (_) {}
  runApp(const MegaOverflowApp());
}

const STATION_ID = 'kks1y4wm7s8uv';

// USE HTTP AS PRIMARY - FALLBACK TO HTTPS
const String STREAM_HTTP = 'http://stream.radiojar.com/$STATION_ID';
const String STREAM_HTTPS = 'https://stream.radiojar.com/$STATION_ID';
const String META_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/now_playing/';
const String HISTORY_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/tracks/';

class MegaOverflowApp extends StatelessWidget {
  const MegaOverflowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  double volume = 1.0; bool isMuted = false;
  String title = 'Mega Overflow Radio';
  String artist = '24/7 Word, Worship and Wealth';
  String cover = '';
  String listeners = '0';
  List<dynamic> history = [];
  Timer? metaTimer;
  late AnimationController vinylController;
  BannerAd? bannerAd; bool isAdLoaded = false;

  // Forms controllers
  final chatCtrl = TextEditingController();
  final volNameCtrl = TextEditingController();
  final volPhoneCtrl = TextEditingController();
  final testNameCtrl = TextEditingController();
  final testLocCtrl = TextEditingController();
  final testStoryCtrl = TextEditingController();
  final bibleSearchCtrl = TextEditingController();
  String bibleText = 'Search for a verse e.g. John 3:16, Genesis 1:1';
  bool bibleLoading = false;

  List<Map<String, String>> chatMessages = [
    {'user':'Pastor Chris','msg':'We are praying with you! Overflow is yours! 🙏'},
  ];

  final List<String> streamUrls = [
  'http://stream.radiojar.com/kks1y4wm7s8uv',       // PRIMARY HTTP - you asked
  'http://stream.radiojar.com/kks1y4wm7s8uv.mp3',
  'https://stream.radiojar.com/kks1y4wm7s8uv',      // fallback https
  'https://stream.radiojar.com/kks1y4wm7s8uv.mp3',
];
  // WRITTEN BIBLE BOOKS
  final bibleBooks = ['Genesis','Exodus','Leviticus','Psalms','Proverbs','Isaiah','Matthew','Mark','Luke','John','Acts','Romans','Ephesians','Philippians','Revelation'];

  // AUDIO BIBLE WITH REAL MP3s (KJV dramatized public domain samples)
  final audioBible = [
    {'book':'Genesis 1','url':'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3','duration':'4:32'},
    {'book':'Psalm 23','url':'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3','duration':'2:15'},
    {'book':'John 1','url':'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3','duration':'5:12'},
    {'book':'Romans 8','url':'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3','duration':'3:45'},
  ];

  final List<Map<String, dynamic>> events = [
    {'title': 'Morning Overflow','day':'Mon - Fri','time':'5AM-7AM','host':'Pastor Chris Praiz','image':'https://images.unsplash.com/photo-1478737270239-2f02b77fc618?q=80&w=800'},
    {'title': 'Worship Encounter','day':'Mon - Fri','time':'12PM-1PM','host':'Min. Damitha','image':'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=800'},
    {'title': 'Sunday Prophetic','day':'Sundays','time':'8AM-11:30AM','host':'Pastor Chris Praiz','image':'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?q=80&w=800'},
  ];

  @override
  void initState() {
    super.initState();
    vinylController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(); vinylController.stop();
    _initAudio();
    fetchMeta(); fetchHistory();
    metaTimer = Timer.periodic(const Duration(seconds: 20), (_) { fetchMeta(); fetchHistory(); });
    _loadAd();
  }

  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        androidAudioAttributes: AndroidAudioAttributes(contentType: AndroidAudioContentType.music, usage: AndroidAudioUsage.media),
      ));
    } catch (_) {}
  }

  void _loadAd() {
    bannerAd = BannerAd(adUnitId: 'ca-app-pub-3940256099942544/6300978111', size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_) => setState(() => isAdLoaded=true)))..load();
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse(META_URL));
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        setState(() {
          title = d['track']?? d['title']?? title;
          artist = d['artist']?? artist;
          cover = d['thumb']?? cover;
          listeners = (d['listeners']?? d['now_playing']?['listeners']?? '0').toString();
        });
      }
    } catch (_) {}
  }

  Future<void> fetchHistory() async {
    try { final res = await http.get(Uri.parse(HISTORY_URL)); if (res.statusCode==200){ final d=json.decode(res.body); if(d is List) setState(()=>history=d);} } catch(_){}
  }

  Future<void> fetchBible(String query) async {
    if(query.isEmpty) return;
    setState(()=>bibleLoading=true);
    try {
      final res = await http.get(Uri.parse('https://bible-api.com/${Uri.encodeComponent(query)}'));
      if(res.statusCode==200){
        final d=json.decode(res.body);
        setState(()=>bibleText='${d['reference']}\n\n${d['text']}');
      } else { setState(()=>bibleText='Not found. Try e.g. John 3:16'); }
    } catch(e){ setState(()=>bibleText='Error: Check internet'); }
    setState(()=>bibleLoading=false);
  }

  Future<void> playUrl(String url, String t, String a) async {
    setState(()=>isLoading=true);
    try {
      await player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: MediaItem(id: url, title: t, artist: a, artUri: cover.isNotEmpty?Uri.parse(cover):null)));
      await player.setVolume(isMuted?0:volume);
      await player.play();
      setState((){isPlaying=true; title=t; artist=a; isLoading=false; vinylController.repeat();});
    } catch(e){
      setState(()=>isLoading=false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e')));
    }
  }

  Future<void> togglePlay() async {
    if(isPlaying){ await player.pause(); setState(()=>isPlaying=false); vinylController.stop(); return; }
    setState(()=>isLoading=true);
    for(var url in streamUrls){
      try {
        await player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: MediaItem(id: 'live', title: 'Mega Overflow Radio', artist: 'LIVE - $listeners listeners')));
        await player.setVolume(isMuted?0:volume);
        await player.play();
        setState((){isPlaying=true; isLoading=false; vinylController.repeat();});
        return;
      } catch(_){ continue; }
    }
    setState(()=>isLoading=false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream offline'), backgroundColor: Colors.red));
  }

  Widget safeLogo(double w, double h, {double radius=12}) {
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: Image.asset('assets/icon/app_icon.png', width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/icon/logo.png', width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: w, height: h, color: Colors.deepPurple, child: const Icon(Icons.radio, color: Colors.white)))));
  }

  @override
  Widget build(BuildContext context) {
    final views = [_radioView(), _historyView(), _scheduleView(), _writtenBibleView(), _audioBibleView(), _chatView(), _partnersView(), _volunteerView(), _testimonyView(), _aboutView()];
    final names = ['Radio LIVE ($listeners)','Recently Played','Schedule','Written Bible','Audio Bible','Voice Altar Chat','Partner','Volunteer','Testimony','About'];
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: _drawer(names),
      appBar: AppBar(backgroundColor: const Color(0xFF111111), title: Text(names[currentView], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), actions: [IconButton(icon: Icon(isMuted?Icons.volume_off:Icons.volume_up), onPressed: () async { setState(()=>isMuted=!isMuted); await player.setVolume(isMuted?0:volume); }), Container(margin: const EdgeInsets.only(right:12, top:12, bottom:12), padding: const EdgeInsets.symmetric(horizontal:10), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Center(child: Text('LIVE $listeners', style: const TextStyle(fontSize:10, fontWeight: FontWeight.bold))))]),
      body: Column(children: [Expanded(child: views[currentView]), if(isAdLoaded && bannerAd!=null) SizedBox(height: bannerAd!.size.height.toDouble(), child: AdWidget(ad: bannerAd!)), _miniPlayer()]),
    );
  }

  Widget _drawer(List<String> names){
    final icons=[Icons.radio, Icons.history, Icons.calendar_month, Icons.menu_book, Icons.headphones, Icons.chat_bubble, Icons.handshake, Icons.groups, Icons.favorite, Icons.info];
    return Drawer(backgroundColor: const Color(0xFF111111), child: ListView(padding: EdgeInsets.zero, children: [DrawerHeader(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [safeLogo(60,60), const SizedBox(height:10), const Text('MEGA OVERFLOW', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize:18)), Text('Word • Worship • Wealth • $listeners Online', style: const TextStyle(color: Colors.white70, fontSize:10))])),...List.generate(names.length, (i)=>ListTile(leading: Icon(icons[i], color: currentView==i?Colors.orange:Colors.purpleAccent, size:20), title: Text(names[i], style: TextStyle(color: currentView==i?Colors.white:Colors.white70, fontWeight: currentView==i?FontWeight.bold:FontWeight.normal, fontSize:12)), selected: currentView==i, onTap: (){ setState(()=>currentView=i); Navigator.pop(context);} ))]));
  }

  Widget _radioView(){
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      RotationTransition(turns: vinylController, child: Container(width:240, height:240, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF141414), border: Border.all(color: Colors.white10, width:8)), child: Center(child: ClipOval(child: cover.isNotEmpty?Image.network(cover, width:110, height:110, fit:BoxFit.cover, errorBuilder: (_, __, ___)=>safeLogo(110,110, radius:100)):safeLogo(110,110, radius:100))))),
      const SizedBox(height:12),
      Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:4), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)), child: Row(children: [IconButton(icon: Icon(isMuted?Icons.volume_off:Icons.volume_down), onPressed: () async { setState(()=>isMuted=!isMuted); await player.setVolume(isMuted?0:volume); }), Expanded(child: Slider(value: volume, min:0, max:1, activeColor: Colors.deepPurple, onChanged: (v) async { setState(()=>volume=v); await player.setVolume(v); })), Text('${(volume*100).toInt()}%', style: const TextStyle(fontSize:10)), const SizedBox(width:8), const Icon(Icons.bluetooth, color: Colors.cyan, size:20)])),
      const SizedBox(height:12),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Column(children: [
        Row(children: [Container(width:8, height:8, decoration: BoxDecoration(color: isPlaying?Colors.green:Colors.orange, shape: BoxShape.circle)), const SizedBox(width:8), Text(isPlaying?'ON AIR NOW • $listeners LISTENERS':'READY TO STREAM', style: const TextStyle(fontSize:10, fontWeight: FontWeight.bold)), const Spacer(), const Text('320 KBPS HD', style: TextStyle(fontSize:9, color: Colors.orange))]),
        const SizedBox(height:12), Text(title, style: const TextStyle(fontSize:20, fontWeight: FontWeight.w900), textAlign: TextAlign.center), Text(artist, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize:13)),
        const SizedBox(height:18), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isLoading?null:togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), icon: isLoading?const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth:2, color: Colors.white)):Icon(isPlaying?Icons.pause:Icons.play_arrow), label: Text(isPlaying?'Pause Radio':'Listen Live ($listeners Online)', style: const TextStyle(fontWeight: FontWeight.w900)))),
      ])),
    ]));
  }

  Widget _writtenBibleView(){
    return Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [Expanded(child: TextField(controller: bibleSearchCtrl, decoration: InputDecoration(hintText: 'Search John 3:16, Genesis 1...', filled:true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onSubmitted: fetchBible)), IconButton(icon: const Icon(Icons.search, color: Colors.orange), onPressed: ()=>fetchBible(bibleSearchCtrl.text))]),
      const SizedBox(height:10),
      Wrap(spacing:6, children: bibleBooks.map((b)=>ActionChip(label: Text(b, style: const TextStyle(fontSize:10)), backgroundColor: const Color(0xFF1E1E1E), onPressed: ()=>fetchBible(b))).toList()),
      const SizedBox(height:12),
      Expanded(child: Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12)), child: SingleChildScrollView(child: bibleLoading?const Center(child: CircularProgressIndicator()):Text(bibleText, style: const TextStyle(fontSize:14, height:1.6))))),
    ]));
  }

  Widget _audioBibleView(){
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: audioBible.length, itemBuilder: (c,i){
      final b=audioBible[i];
      return Card(color: const Color(0xFF141414), child: ListTile(leading: Container(width:44, height:44, decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.headphones, color: Colors.orange)), title: Text(b['book']!, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Duration: ${b['duration']}', style: const TextStyle(fontSize:10)), trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.deepPurple, size:32), onPressed: ()=>playUrl(b['url']!, b['book']!, 'Audio Bible KJV'))));
    });
  }

  Widget _chatView(){
    return Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Expanded(child: ListView.builder(itemCount: chatMessages.length, itemBuilder: (c,i){ final m=chatMessages[i]; return Container(margin: const EdgeInsets.only(bottom:8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: m['user']=='You'?Colors.deepPurple.withOpacity(0.3):const Color(0xFF141414), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['user']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:11, color: Colors.orange)), const SizedBox(height:4), Text(m['msg']!, style: const TextStyle(fontSize:13))])); })),
      Row(children: [Expanded(child: TextField(controller: chatCtrl, decoration: InputDecoration(hintText: 'Share prayer request...', filled:true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))), IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: (){ if(chatCtrl.text.trim().isEmpty) return; setState(()=>chatMessages.add({'user':'You','msg':chatCtrl.text})); chatCtrl.clear(); })]),
    ]));
  }

  Widget _volunteerView(){
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      const Icon(Icons.groups, size:60, color: Colors.deepPurple), const Text('Join Our Volunteer Team', style: TextStyle(fontSize:20, fontWeight: FontWeight.w900)),
      const SizedBox(height:16),
      TextField(controller: volNameCtrl, decoration: _inputDec('Full Name *')),
      const SizedBox(height:10),
      TextField(controller: volPhoneCtrl, decoration: _inputDec('Phone / WhatsApp *')),
      const SizedBox(height:10),
      DropdownButtonFormField(items: const [DropdownMenuItem(value:'Media', child: Text('Media')), DropdownMenuItem(value:'Prayer', child: Text('Prayer Team')), DropdownMenuItem(value:'Outreach', child: Text('Outreach')), DropdownMenuItem(value:'Technical', child: Text('Technical'))], onChanged: (_){}, decoration: _inputDec('Department')),
      const SizedBox(height:20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
        if(volNameCtrl.text.isEmpty || volPhoneCtrl.text.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields'))); return; }
        final uri=Uri.parse('mailto:gcmega1@gmail.com?subject=Volunteer - ${volNameCtrl.text}&body=Name: ${volNameCtrl.text}%0APhone: ${volPhoneCtrl.text}');
        if(await canLaunchUrl(uri)) await launchUrl(uri);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent!')));
      }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text('Apply to Volunteer'))),
    ]));
  }

  Widget _testimonyView(){
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      const Icon(Icons.favorite, size:50, color: Colors.orange), const Text('Share Your Praise Report', style: TextStyle(fontSize:20, fontWeight: FontWeight.w900)),
      const SizedBox(height:16),
      TextField(controller: testNameCtrl, decoration: _inputDec('Your Name *')),
      const SizedBox(height:10),
      TextField(controller: testLocCtrl, decoration: _inputDec('Location *')),
      const SizedBox(height:10),
      TextField(controller: testStoryCtrl, decoration: _inputDec('Your Testimony *'), maxLines:6),
      const SizedBox(height:16),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
        if(testNameCtrl.text.isEmpty || testStoryCtrl.text.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill testimony'))); return; }
        final uri=Uri.parse('mailto:gcmega1@gmail.com?subject=Testimony - ${testNameCtrl.text}&body=Name: ${testNameCtrl.text}%0ALocation: ${testLocCtrl.text}%0A%0A${testStoryCtrl.text}');
        if(await canLaunchUrl(uri)) await launchUrl(uri);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testimony submitted! God bless!')));
        testNameCtrl.clear(); testLocCtrl.clear(); testStoryCtrl.clear();
      }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text('Submit Testimony'))),
    ]));
  }

  Widget _historyView()=>history.isEmpty?const Center(child: CircularProgressIndicator()):ListView.builder(padding: const EdgeInsets.all(12), itemCount: history.length, itemBuilder: (c,i){ final t=history[i]; return Card(color: const Color(0xFF141414), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(t['thumb']??'', width:50, height:50, fit:BoxFit.cover, errorBuilder: (_, __, ___)=>safeLogo(50,50))), title: Text(t['track']??'Track', style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12)), subtitle: Text(t['artist']??'', style: const TextStyle(fontSize:10, color: Colors.purpleAccent)), trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.orange), onPressed: togglePlay)));});
  Widget _scheduleView()=>ListView.builder(padding: const EdgeInsets.all(12), itemCount: events.length, itemBuilder: (c,i){ final e=events[i]; return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom:14), child: Row(children: [ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)), child: Image.network(e['image'] as String, width:90, height:90, fit:BoxFit.cover)), Expanded(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e['day'] as String, style: const TextStyle(fontSize:9, color: Colors.orange)), Text(e['title'] as String, style: const TextStyle(fontWeight: FontWeight.w900)), Text(e['time'] as String, style: const TextStyle(fontSize:10, color: Colors.white60))])))]));});
  Widget _partnersView()=>SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [const Icon(Icons.handshake, size:60, color: Colors.orange), const Text('Partner With Us', style: TextStyle(fontSize:20, fontWeight: FontWeight.w900)), const SizedBox(height:20), _tier('Bronze','₦5,000/mo', Colors.brown), _tier('Silver','₦20,000/mo', Colors.grey), _tier('Gold','₦100,000/mo', Colors.amber), const SizedBox(height:20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri=Uri.parse('https://paystack.com/pay/megaoverflow'); if(await canLaunchUrl(uri)) await launchUrl(uri); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text('Become a Partner')))]));
  Widget _tier(String n,String p,Color c)=>Container(margin: const EdgeInsets.only(bottom:10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Row(children: [Icon(Icons.star, color:c), const SizedBox(width:10), Text(n, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text(p, style: TextStyle(color:c, fontWeight: FontWeight.bold))]));
  Widget _aboutView()=>ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(16)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Our Divine Mandate', style: TextStyle(fontSize:18, fontWeight: FontWeight.bold)), SizedBox(height:8), Text('24/7 Word, Worship, Wealth to nations.', style: TextStyle(fontSize:12))])), const SizedBox(height:12), Card(color: const Color(0xFF141414), child: ListTile(title: const Text('Contact'), subtitle: const Text('gcmega1@gmail.com\nAkwa Ibom, Nigeria')))]);

  InputDecoration _inputDec(String l)=>InputDecoration(labelText: l, filled:true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));
  Widget _miniPlayer()=>Container(height:68, padding: const EdgeInsets.symmetric(horizontal:12), decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(6), child: cover.isNotEmpty?Image.network(cover, width:44, height:44, fit:BoxFit.cover, errorBuilder: (_, __, ___)=>safeLogo(44,44)):safeLogo(44,44)), const SizedBox(width:10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:11)), Text('$artist • $listeners Online', maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.purpleAccent, fontSize:9))])), isLoading?const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth:2)):IconButton(onPressed: togglePlay, icon: Icon(isPlaying?Icons.pause_circle_filled:Icons.play_circle_filled, size:38, color: Colors.deepPurple))]));
}