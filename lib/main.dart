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
      title: 'MegaOverflow Radio',
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
  bool isBookPlaying = false;
  String title = "MIDWEEK COMMUNION SERVICE";
  String artist = "Word, Worship and Wealth";
  String cover = "";
  List<dynamic> history = [];
  late AnimationController vinyl;
  BannerAd? bannerAd;
  bool isAdLoaded = false;
  Timer? sleepTimer;
  int sleepMin = 0;

  // Controllers
  final chatCtrl = TextEditingController();
  final bibleSearchCtrl = TextEditingController();
  final volName = TextEditingController();
  final volPhone = TextEditingController();
  final testName = TextEditingController();
  final testLoc = TextEditingController();
  final testMsg = TextEditingController();

  List<Map<String,String>> chatMsgs = [
    {'user':'Pastor Chris','msg':'Welcome to Voice Altar! Share prayer, we pray 24/7 🔥'},
  ];
  String bibleFilter = '';

  final List<String> bibleBooks = ["Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark","Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John","Jude","Revelation"];

  List<String> get filteredBible => bibleBooks.where((b) => b.toLowerCase().contains(bibleFilter.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    vinyl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    vinyl.stop();
    fetchMeta();
    Timer.periodic(const Duration(seconds: 20), (_) => fetchMeta());
    _loadAd();
  }

  void _loadAd() {
    try {
      bannerAd = BannerAd(adUnitId: 'ca-app-pub-3940256099942544/6300978111', size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_) => setState(() => isAdLoaded=true), onAdFailedToLoad: (_,__) => setState(() => isAdLoaded=false)))..load();
    } catch(_){}
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/'));
      if(res.statusCode==200){ final d=json.decode(res.body); if(mounted) setState((){ title=d['track']??d['title']??title; artist=d['artist']??artist; cover=d['thumb']??cover; }); }
      final his = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/'));
      if(his.statusCode==200 && mounted) setState(()=> history=json.decode(his.body));
    } catch(_){}
  }

  Future<void> togglePlay() async {
    if(isPlaying){ await player.pause(); setState(()=>isPlaying=false); vinyl.stop(); sleepTimer?.cancel(); return; }
    setState(()=>isLoading=true);
    const urls=['https://stream.radiojar.com/kks1y4wm7s8uv','https://stream.radiojar.com/kks1y4wm7s8uv.mp3','http://stream.radiojar.com/kks1y4wm7s8uv','https://stream.radiojar.com/kks1y4wm7s8uv.m3u'];
    for(var u in urls){
      try{ await player.setAudioSource(AudioSource.uri(Uri.parse(u))); await player.play(); setState((){isPlaying=true; isLoading=false;}); vinyl.repeat(); return; } catch(e){ continue; }
    }
    setState(()=>isLoading=false);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream offline, try again'), backgroundColor: Colors.red));
  }

  Future<void> playBook(String title) async {
    try{
      if(isBookPlaying){ await bookPlayer.stop(); }
      // Play radio as book demo + real book URLs can be added
      await bookPlayer.setAudioSource(AudioSource.uri(Uri.parse('https://stream.radiojar.com/kks1y4wm7s8uv')));
      await bookPlayer.play();
      setState(()=>isBookPlaying=true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing: $title'), backgroundColor: Colors.orange));
      bookPlayer.playerStateStream.listen((s){ if(s.processingState==ProcessingState.completed) setState(()=>isBookPlaying=false); });
    } catch(_){}
  }

  void setSleepTimer(int mins){
    sleepTimer?.cancel();
    if(mins==0){ setState(()=>sleepMin=0); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep timer off'))); return; }
    setState(()=>sleepMin=mins);
    sleepTimer=Timer(Duration(minutes: mins), () async { await player.pause(); await bookPlayer.pause(); setState((){isPlaying=false; isBookPlaying=false; sleepMin=0;}); vinyl.stop(); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sleep timer: $mins min'), backgroundColor: Colors.deepPurple));
  }

  Future<void> submitVolunteer() async {
    if(volName.text.isEmpty || volPhone.text.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill name and phone'))); return; }
    final msg="Volunteer Application\nName: ${volName.text}\nPhone: ${volPhone.text}\nStation: Mega Overflow";
    final uri=Uri.parse('https://wa.me/2340000000000?text=${Uri.encodeComponent(msg)}');
    if(await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Volunteer sent via WhatsApp!'), backgroundColor: Colors.green));
    volName.clear(); volPhone.clear();
  }

  Future<void> submitTestimony() async {
    if(testName.text.isEmpty || testMsg.text.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill name and testimony'))); return; }
    final uri=Uri.parse('mailto:gcmega1@gmail.com?subject=Testimony - ${testName.text}&body=${Uri.encodeComponent("Name: ${testName.text}\nLocation: ${testLoc.text}\nTestimony: ${testMsg.text}")}');
    if(await canLaunchUrl(uri)) await launchUrl(uri);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Testimony sent! Thank you'), backgroundColor: Colors.green));
    testName.clear(); testLoc.clear(); testMsg.clear();
  }

  Widget logo(double w, double h, {double r=12}){
    return ClipRRect(borderRadius: BorderRadius.circular(r), child: Image.asset('assets/icon/app_icon.png', width: w, height: h, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Image.asset('assets/icon/logo.png', width: w, height: h, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(width: w, height: h, color: Colors.orange, child: const Icon(Icons.radio, color: Colors.white)))));
  }

  @override
  void dispose(){ player.dispose(); bookPlayer.dispose(); vinyl.dispose(); bannerAd?.dispose(); chatCtrl.dispose(); bibleSearchCtrl.dispose(); sleepTimer?.cancel(); super.dispose(); }

  final tabNames=['Radio','Recently Played','Schedule','Sermons','E-Books & Library','Audio Bible','Audiobooks','Chat & Voice Altar','Partner With Us','Volunteer','Testimony','About Us'];
  final tabIcons=[Icons.radio, Icons.history, Icons.calendar_month, Icons.mic, Icons.menu_book, Icons.headphones, Icons.album, Icons.chat_bubble, Icons.handshake, Icons.groups, Icons.favorite, Icons.info];

  @override
  Widget build(BuildContext context){
    return Scaffold(
      drawer: Drawer(backgroundColor: const Color(0xFF111111), child: Column(children: [
        Container(height: 190, width: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])), child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: logo(85,85,r:18)), const SizedBox(height:10), const Text('MEGA OVERFLOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize:16, letterSpacing:1)), const Text('Word • Worship • Wealth', style: TextStyle(color: Colors.white70, fontSize:11))]))),
        Expanded(child: ListView.builder(padding: EdgeInsets.zero, itemCount: tabNames.length, itemBuilder: (c,i)=> ListTile(leading: Icon(tabIcons[i], color: currentView==i? Colors.orange : Colors.purpleAccent, size:20), title: Text(tabNames[i], style: TextStyle(fontSize:12.5, fontWeight: currentView==i? FontWeight.bold : FontWeight.normal, color: currentView==i? Colors.white : Colors.white70)), selected: currentView==i, selectedTileColor: Colors.purple.withOpacity(0.15), onTap: (){ setState(()=>currentView=i); Navigator.pop(context); }))),
        ListTile(leading: Icon(widget.isDark? Icons.light_mode : Icons.dark_mode, color: Colors.white70), title: Text(widget.isDark? 'Light Mode' : 'Dark Mode', style: const TextStyle(fontSize:12)), onTap: widget.onTheme),
      ])),
      appBar: AppBar(backgroundColor: const Color(0xFF111111), title: Text(tabNames[currentView], style: const TextStyle(fontSize:15, fontWeight: FontWeight.bold)), actions: [
        PopupMenuButton<int>(icon: Icon(sleepMin>0? Icons.timer : Icons.timer_outlined, color: sleepMin>0? Colors.orange : Colors.white), onSelected: setSleepTimer, itemBuilder: (_)=> [const PopupMenuItem(value:0, child: Text('Timer Off')), const PopupMenuItem(value:15, child: Text('15 min')), const PopupMenuItem(value:30, child: Text('30 min')), const PopupMenuItem(value:60, child: Text('60 min')), const PopupMenuItem(value:90, child: Text('90 min'))]),
        Container(margin: const EdgeInsets.only(right:12, top:10, bottom:10), padding: const EdgeInsets.symmetric(horizontal:14), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(sleepMin>0? '${sleepMin}m' : 'LIVE', style: const TextStyle(fontSize:11, fontWeight: FontWeight.bold, color: Colors.white)))),
      ]),
      body: Column(children: [
        Expanded(child: IndexedStack(index: currentView, children: [_radioView(), _historyView(), _scheduleView(), _sermonsView(), _ebooksView(), _bibleView(), _audiobooksView(), _chatView(), _partnersView(), _volunteerView(), _testimonyView(), _aboutView()])),
        if(isAdLoaded && bannerAd!=null) Container(color: Colors.black, height: bannerAd!.size.height.toDouble(), width: double.infinity, child: AdWidget(ad: bannerAd!)),
        _miniPlayer(),
      ]),
    );
  }

  Widget _radioView()=> Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A0A0A), Color(0xFF000000)])), child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
    const SizedBox(height:10),
    RotationTransition(turns: vinyl, child: Container(width:260, height:260, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF141414), border: Border.all(color: const Color(0xFF2A2A2A), width:12)), child: Center(child: Container(width:125, height:125, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width:6)), child: ClipOval(child: cover.isNotEmpty? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_,__,___)=> logo(125,125,r:60)) : logo(125,125,r:60))))))),
    const SizedBox(height:28),
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Column(children: [
      Row(children: [Container(width:8, height:8, decoration: BoxDecoration(color: isPlaying? Colors.green : Colors.orange, shape: BoxShape.circle)), const SizedBox(width:8), Text(isPlaying? 'ON AIR NOW' : 'READY TO STREAM', style: const TextStyle(fontSize:10, fontWeight: FontWeight.bold, letterSpacing:2)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('320 KBPS HD', style: TextStyle(fontSize:9, color: Colors.orange)))]),
      const SizedBox(height:16), Text(title, style: const TextStyle(fontSize:22, fontWeight: FontWeight.w900), textAlign: TextAlign.center, maxLines:2), const SizedBox(height:6), Text(artist, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize:13), textAlign: TextAlign.center), const SizedBox(height:20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isLoading? null : togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), icon: isLoading? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth:2, color: Colors.white)) : Icon(isPlaying? Icons.pause : Icons.play_arrow, size:28), label: Text(isPlaying? 'Pause Radio' : 'Listen Live', style: const TextStyle(fontWeight: FontWeight.w900, fontSize:15)))),
    ])),
  ])));

  Widget _historyView()=> history.isEmpty? const Center(child: CircularProgressIndicator(color: Colors.deepPurple)) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: history.length, itemBuilder: (_,i){ final t=history[i]; return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom:8), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(t['thumb']??'', width:50, height:50, fit: BoxFit.cover, errorBuilder: (_,__,___)=> logo(50,50,r:8))), title: Text(t['track']??t['title']??'Track', style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12), maxLines:1), subtitle: Text(t['artist']??'Mega Overflow', style: const TextStyle(color: Colors.purpleAccent, fontSize:10)), trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.orange), onPressed: togglePlay)));});

  Widget _scheduleView()=> ListView.builder(padding: const EdgeInsets.all(12), itemCount: 4, itemBuilder: (_,i){ final events=[{'title':'Morning Overflow','day':'Mon - Fri','time':'5:00 AM - 7:00 AM','host':'Pastor Chris Praiz'},{'title':'Worship Encounter','day':'Mon - Fri','time':'12:00 PM - 1:00 PM','host':'Min. Damitha'},{'title':'Wealth Wisdom','day':'Wed & Fri','time':'7:00 PM - 8:30 PM','host':'Pastor Chris'},{'title':'Sunday Prophetic Service','day':'Sundays','time':'8:00 AM - 11:30 AM','host':'Pastor Chris Praiz'}]; final e=events[i]; return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom:12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: ListTile(leading: Container(width:48, height:48, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month, color: Colors.orange)), title: Text(e['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:13)), subtitle: Text('${e['day']} • ${e['time']}\nHost: ${e['host']}', style: const TextStyle(fontSize:10, color: Colors.white60)), isThreeLine:true));});

  Widget _sermonsView()=> ListView.builder(padding: const EdgeInsets.all(12), itemCount: 4, itemBuilder: (_,i){ final sermons=[{'title':'The Overflow Anointing','preacher':'Pastor Chris Praiz','duration':'45:23'},{'title':'Wealth Transfer','preacher':'Pastor Chris Praiz','duration':'38:12'},{'title':'Worship That Opens Heaven','preacher':'Min. Damitha','duration':'52:10'},{'title':'Faith For Overflow','preacher':'Pastor Chris Praiz','duration':'41:15'}]; final s=sermons[i]; return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom:10), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: logo(55,55,r:8)), title: Text(s['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12)), subtitle: Text('${s['preacher']} • ${s['duration']}', style: const TextStyle(fontSize:10)), trailing: const Icon(Icons.play_arrow, color: Colors.deepPurple)));});

  Widget _ebooksView()=> GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2, childAspectRatio:0.68, crossAxisSpacing:12, mainAxisSpacing:12), itemCount:6, itemBuilder: (_,i)=> Card(color: const Color(0xFF141414), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: Column(children: [Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: logo(double.infinity, double.infinity, r:0))), const Padding(padding: EdgeInsets.all(8), child: Column(children: [Text('Overflow Principles', style: TextStyle(fontWeight: FontWeight.bold, fontSize:11), textAlign: TextAlign.center), Text('Chris Praiz', style: TextStyle(fontSize:9, color: Colors.purpleAccent))]))])));

  Widget _bibleView(){
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: bibleSearchCtrl, onChanged: (v)=> setState(()=> bibleFilter=v), decoration: InputDecoration(hintText: 'Search scripture or book... e.g. Genesis, John, Psalm', prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent), filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal:14, vertical:12)))),
      Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal:12), itemCount: filteredBible.length, itemBuilder: (_,i){ final b=filteredBible[i]; final idx=bibleBooks.indexOf(b); return Card(color: const Color(0xFF141414), child: ListTile(leading: Container(width:38, height:38, decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${idx+1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12)))), title: Text(b, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:13)), subtitle: Text('Chapters: ${b=="Psalms"?150: b=="Genesis"?50:30} • Tap to listen', style: const TextStyle(fontSize:9, color: Colors.white54)), trailing: const Icon(Icons.headphones, color: Colors.orange, size:20), onTap: ()=> playBook('Audio Bible: $b')));}))
    ]);
  }

  Widget _audiobooksView()=> ListView.builder(padding: const EdgeInsets.all(12), itemCount: 8, itemBuilder: (_,i)=> Card(color: const Color(0xFF141414), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: logo(50,50,r:8)), title: Text('Kingdom Wealth - Part ${i+1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12)), subtitle: Text(isBookPlaying? 'Playing now...' : 'Audiobook • 2h 14m • Tap to play', style: const TextStyle(fontSize:10, color: Colors.white54)), trailing: ElevatedButton(onPressed: ()=> playBook('Kingdom Wealth Part ${i+1}'), style: ElevatedButton.styleFrom(backgroundColor: isBookPlaying? Colors.green : Colors.orange, minimumSize: const Size(60,30)), child: Text(isBookPlaying? 'Stop' : 'Play', style: const TextStyle(fontSize:10, color: Colors.black, fontWeight: FontWeight.bold))))));

  Widget _chatView(){
    return Column(children: [
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: chatMsgs.length, itemBuilder: (_,i){ final m=chatMsgs[i]; final isMe=m['user']=='You'; return Align(alignment: isMe? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom:10), padding: const EdgeInsets.all(12), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width*0.75), decoration: BoxDecoration(color: isMe? Colors.deepPurple : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['user']!, style: TextStyle(fontSize:9, fontWeight: FontWeight.bold, color: isMe? Colors.white70 : Colors.orange)), const SizedBox(height:4), Text(m['msg']!, style: const TextStyle(fontSize:12))]))); })),
      Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [
        IconButton(icon: const Icon(Icons.mic, color: Colors.orange), onPressed: () async { final uri=Uri.parse('https://wa.me/2348039683555?text=Voice Altar Prayer Request:'); if(await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }, tooltip: 'Voice Altar - Send Voice Note'),
        Expanded(child: TextField(controller: chatCtrl, decoration: InputDecoration(hintText: 'Type prayer request...', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal:16, vertical:10)), onSubmitted: (_)=> _sendChat())),
        const SizedBox(width:8), CircleAvatar(backgroundColor: Colors.deepPurple, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size:18), onPressed: _sendChat)),
      ])),
    ]);
  }

  void _sendChat(){ if(chatCtrl.text.trim().isEmpty) return; setState((){ chatMsgs.add({'user':'You','msg':chatCtrl.text.trim()}); chatMsgs.add({'user':'Pastor Chris','msg':'Received: "${chatCtrl.text.trim()}" - We are praying! 🙏'}); }); chatCtrl.clear(); }

  Widget _partnersView()=> SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    logo(85,85,r:18), const SizedBox(height:12), const Text('Partner With Mega Overflow', style: TextStyle(fontSize:20, fontWeight: FontWeight.w900)), const SizedBox(height:6), const Text('Tap any category to partner - All tiers clickable', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize:11)), const SizedBox(height:20),
    _tierClickable('Bronze Partner','₦5,000/month',Colors.brown,'5000'),
    _tierClickable('Silver Partner','₦20,000/month',Colors.grey,'20000'),
    _tierClickable('Gold Partner','₦100,000/month',Colors.amber,'100000'),
    _tierClickable('Platinum Partner','₦500,000/month',Colors.purpleAccent,'500000'),
    _tierClickable('Diamond Partner','₦1,000,000/month',Colors.cyan,'1000000'),
    const SizedBox(height:20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri=Uri.parse('https://paystack.com/pay/megaoverflow'); if(await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Custom Amount', style: TextStyle(fontWeight: FontWeight.bold)))),
  ]));

  Widget _tierClickable(String name,String price,Color c,String amount)=> InkWell(onTap: () async { final uri=Uri.parse('https://paystack.com/pay/megaoverflow?amount=$amount'); if(await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); else if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $name $price'))); }, borderRadius: BorderRadius.circular(12), child: Container(margin: const EdgeInsets.only(bottom:12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.5))), child: Row(children: [Icon(Icons.star, color:c), const SizedBox(width:10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:13)), Text(price, style: TextStyle(color:c, fontWeight: FontWeight.bold, fontSize:11))])), const Icon(Icons.arrow_forward_ios, size:14, color: Colors.white30)])));

  Widget _volunteerView()=> Padding(padding: const EdgeInsets.all(16), child: ListView(children: [Center(child: logo(60,60)), const SizedBox(height:12), const Text('Join Our Team', style: TextStyle(fontSize:20, fontWeight: FontWeight.w900), textAlign: TextAlign.center), const SizedBox(height:16), TextField(controller: volName, decoration: _inputDec('Full Name *')), const SizedBox(height:12), TextField(controller: volPhone, decoration: _inputDec('Phone / WhatsApp *')), const SizedBox(height:12), DropdownButtonFormField<String>(items: const [DropdownMenuItem(value:'Media', child: Text('Media Team')), DropdownMenuItem(value:'Prayer', child: Text('Prayer Team')), DropdownMenuItem(value:'Outreach', child: Text('Outreach Team')), DropdownMenuItem(value:'Technical', child: Text('Technical Team'))], onChanged: (_){}, decoration: _inputDec('Department')), const SizedBox(height:20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: submitVolunteer, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text('Apply to Volunteer - Submit')))]));

  Widget _testimonyView()=> SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [Center(child: logo(60,60)), const SizedBox(height:12), const Text('Share Your Testimonies', style: TextStyle(fontSize:20, fontWeight: FontWeight.w900)), const SizedBox(height:16), TextField(controller: testName, decoration: _inputDec('Your Name *')), const SizedBox(height:12), TextField(controller: testLoc, decoration: _inputDec('Location')), const SizedBox(height:12), TextField(controller: testMsg, decoration: _inputDec('Your Testimony *'), maxLines:5), const SizedBox(height:16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: submitTestimony, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text('Submit Testimony - Send')))]));

  Widget _aboutView()=> ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [logo(40,40,r:8), const SizedBox(width:10), const Text('Our Divine Mandate', style: TextStyle(fontSize:18, fontWeight: FontWeight.bold, color: Colors.white))]), const SizedBox(height:10), const Text('Mega Overflow Radio is a premier 24/7 internet radio station dedicated to delivering transformative gospel broadcasts: Word, Worship, and Wealth encounters.', style: TextStyle(color: Colors.white, fontSize:12.5))])), const SizedBox(height:12), _aboutCard('Vision','To saturate the airwaves with the overflow of God\'s presence and power.'), _aboutCard('Mission','24/7 Word, Worship, and Wealth to every nation.'), _aboutCard('Contact','Email: gcmega1@gmail.com\nPhone: +2348039683555\nPhone: +2348065241229\nLocation: Abuja, Nigeria')]);

  Widget _aboutCard(String t,String d)=> Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom:10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize:13)), const SizedBox(height:6), Text(d, style: const TextStyle(color: Colors.white70, fontSize:12))])));

  InputDecoration _inputDec(String label)=> InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal:14, vertical:14));

  Widget _miniPlayer()=> Container(height:68, padding: const EdgeInsets.symmetric(horizontal:12), decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(6), child: cover.isNotEmpty? Image.network(cover, width:44, height:44, fit: BoxFit.cover, errorBuilder: (_,__,___)=> logo(44,44,r:6)) : logo(44,44,r:6)), const SizedBox(width:10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:11)), Text(artist, maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.purpleAccent, fontSize:9)), if(sleepMin>0) Text('Sleep: ${sleepMin}m', style: const TextStyle(color: Colors.orange, fontSize:8))])), isLoading? const SizedBox(width:24, height:24, child: CircularProgressIndicator(strokeWidth:2)) : IconButton(onPressed: togglePlay, icon: Icon(isPlaying? Icons.pause_circle_filled : Icons.play_circle_filled, size:42, color: Colors.deepPurple))]));
}
