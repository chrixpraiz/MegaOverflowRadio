import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.megaoverflow.radio',
    androidNotificationChannelName: 'Mega Overflow',
    androidNotificationOngoing: true,
  );
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
      themeMode: isDark? ThemeMode.dark : ThemeMode.light,
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
  double volume = 1.0;
  bool isMuted = false;
  String title = "MIDWEEK COMMUNION SERVICE";
  String artist = "Word, Worship and Wealth";
  String cover = "";
  List<dynamic> history = [];
  late AnimationController vinyl;
  BannerAd? bannerAd;
  bool isAdLoaded = false;
  Timer? sleepTimer;
  int sleepMin = 0;

  final chatCtrl = TextEditingController();
  final bibleSearchCtrl = TextEditingController();
  final volName = TextEditingController();
  final volPhone = TextEditingController();
  final testName = TextEditingController();
  final testMsg = TextEditingController();
  List<Map<String,String>> chatMsgs = [{'user':'Pastor Chris','msg':'Welcome to Voice Altar!'}];
  String bibleFilter = '';

  final List<String> tabNames = ['Radio','Recently Played','Schedule','Sermons','E-Books','Audio Bible','Audiobooks','Chat','Partner','Volunteer','Testimony','About'];
  final List<IconData> tabIcons = [Icons.radio, Icons.history, Icons.calendar_month, Icons.mic, Icons.menu_book, Icons.headphones, Icons.album, Icons.chat_bubble, Icons.handshake, Icons.groups, Icons.favorite, Icons.info];
  final List<String> bibleBooks = ["Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark","Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John","Jude","Revelation"];
  List<String> get filteredBible => bibleBooks.where((b) => b.toLowerCase().contains(bibleFilter.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    initSession();
    vinyl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    vinyl.stop();
    fetchMeta();
    Timer.periodic(const Duration(seconds: 20), (_) => fetchMeta());
    loadAd();
  }

  Future<void> initSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        androidAudioAttributes: AndroidAudioAttributes(contentType: AndroidAudioContentType.music, usage: AndroidAudioUsage.media),
      ));
    } catch (_) {}
  }

  void loadAd() {
    try {
      bannerAd = BannerAd(adUnitId: 'ca-app-pub-3940256099942544/6300978111', size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_) => setState(() => isAdLoaded = true), onAdFailedToLoad: (_, __) => setState(() => isAdLoaded = false)))..load();
    } catch (_) {}
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/'));
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        if (mounted) setState(() { title = d['track']?? title; artist = d['artist']?? artist; cover = d['thumb']?? cover; });
      }
      final his = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/'));
      if (his.statusCode == 200 && mounted) setState(() => history = json.decode(his.body));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream offline'), backgroundColor: Colors.red));
    }
  }

  Future<void> toggleMute() async {
    setState(() { isMuted =!isMuted; });
    await player.setVolume(isMuted? 0 : volume);
    await bookPlayer.setVolume(isMuted? 0 : volume);
  }

  Future<void> setVolume(double v) async {
    setState(() { volume = v; isMuted = v == 0; });
    await player.setVolume(v);
    await bookPlayer.setVolume(v);
  }

  Future<void> playBook(String name) async {
    if (isBookPlaying) { await bookPlayer.stop(); setState(() => isBookPlaying = false); return; }
    await bookPlayer.setAudioSource(AudioSource.uri(Uri.parse('https://stream.radiojar.com/kks1y4wm7s8uv'), tag: MediaItem(id: name, title: name, artist: 'Mega Overflow')));
    await bookPlayer.setVolume(isMuted? 0 : volume);
    await bookPlayer.play();
    setState(() => isBookPlaying = true);
  }

  void setSleepTimer(int mins) {
    sleepTimer?.cancel();
    if (mins == 0) { setState(() => sleepMin = 0); return; }
    setState(() => sleepMin = mins);
    sleepTimer = Timer(Duration(minutes: mins), () async { await player.pause(); await bookPlayer.pause(); if (mounted) setState(() { isPlaying = false; isBookPlaying = false; sleepMin = 0; }); vinyl.stop(); });
  }

  Widget logo(double w, double h) {
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icon/app_icon.png', width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/icon/logo.png', width: w, height: h, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: w, height: h, color: Colors.orange, child: const Icon(Icons.radio, color: Colors.white)))));
  }

  @override
  void dispose() { player.dispose(); bookPlayer.dispose(); vinyl.dispose(); bannerAd?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(backgroundColor: const Color(0xFF111111), child: Column(children: [
        Container(height: 180, width: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])), child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [logo(70, 70), const Text('MEGA OVERFLOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))),
        Expanded(child: ListView.builder(padding: EdgeInsets.zero, itemCount: tabNames.length, itemBuilder: (c, i) => ListTile(leading: Icon(tabIcons[i], color: currentView == i? Colors.orange : Colors.purpleAccent, size: 20), title: Text(tabNames[i], style: const TextStyle(fontSize: 12)), selected: currentView == i, onTap: () { setState(() => currentView = i); Navigator.pop(context); }))),
        ListTile(leading: Icon(widget.isDark? Icons.light_mode : Icons.dark_mode), title: Text(widget.isDark? 'Light' : 'Dark'), onTap: widget.onTheme),
      ])),
      appBar: AppBar(backgroundColor: const Color(0xFF111111), title: Text(tabNames[currentView], style: const TextStyle(fontSize: 15)), actions: [
        IconButton(icon: Icon(isMuted? Icons.volume_off : Icons.volume_up), onPressed: toggleMute),
        PopupMenuButton<int>(icon: Icon(sleepMin > 0? Icons.timer : Icons.timer_outlined, color: sleepMin > 0? Colors.orange : Colors.white), onSelected: setSleepTimer, itemBuilder: (_) => [const PopupMenuItem(value: 0, child: Text('Timer Off')), const PopupMenuItem(value: 15, child: Text('15 min')), const PopupMenuItem(value: 30, child: Text('30 min')), const PopupMenuItem(value: 60, child: Text('60 min'))]),
        Container(margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: Center(child: Text(sleepMin > 0? '${sleepMin}m' : 'LIVE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
      ]),
      body: Column(children: [
        Expanded(child: IndexedStack(index: currentView, children: [radioView(), historyView(), scheduleView(), sermonsView(), ebooksView(), bibleView(), audiobooksView(), chatView(), partnersView(), volunteerView(), testimonyView(), aboutView()])),
        if (isAdLoaded && bannerAd!= null) SizedBox(height: bannerAd!.size.height.toDouble(), child: AdWidget(ad: bannerAd!)),
        miniPlayer(),
      ]),
    );
  }

  Widget radioView() {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: RotationTransition(turns: vinyl, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 8)), child: ClipOval(child: logo(220, 220))))),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10)), child: Row(children: [
        IconButton(icon: Icon(isMuted? Icons.volume_off : Icons.volume_down), onPressed: toggleMute),
        Expanded(child: Slider(value: volume, min: 0, max: 1, activeColor: Colors.deepPurple, onChanged: setVolume)),
        IconButton(icon: const Icon(Icons.bluetooth, color: Colors.cyan), onPressed: () {}),
      ])),
      const SizedBox(height: 15),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(artist, textAlign: TextAlign.center, style: const TextStyle(color: Colors.purpleAccent)),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isLoading? null : togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 15)), icon: isLoading? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(isPlaying? Icons.pause : Icons.play_arrow), label: Text(isPlaying? 'Pause' : 'Listen Live - Background'))),
      const SizedBox(height: 10),
      const Text('Background + Notification + Bluetooth + Mute + Volume', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.white54)),
    ]);
  }

  Widget historyView() => history.isEmpty? const Center(child: CircularProgressIndicator()) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: history.length, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: logo(45, 45), title: Text(history[i]['track']?? 'Track', style: const TextStyle(fontSize: 12)), trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.orange), onPressed: togglePlay))));

  Widget scheduleView() => ListView(padding: const EdgeInsets.all(12), children: const [Card(color: Color(0xFF141414), child: ListTile(title: Text('Morning Overflow Mon-Fri 5AM'))), Card(color: Color(0xFF141414), child: ListTile(title: Text('Worship Encounter Mon-Fri 12PM')))]);

  Widget sermonsView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: 4, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: logo(50, 50), title: Text('Sermon ${i + 1}'))));

  Widget ebooksView() => GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7), itemCount: 6, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: Column(children: [Expanded(child: logo(double.infinity, double.infinity)), const Padding(padding: EdgeInsets.all(8), child: Text('Book', style: TextStyle(fontSize: 11)))])));

  Widget bibleView() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: bibleSearchCtrl, onChanged: (v) => setState(() => bibleFilter = v), decoration: InputDecoration(hintText: 'Search 66 books...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
      Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: filteredBible.length, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(title: Text(filteredBible[i]), trailing: const Icon(Icons.headphones, color: Colors.orange), onTap: () => playBook('Bible: ${filteredBible[i]}'))))),
    ]);
  }

  Widget audiobooksView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: 8, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: logo(50, 50), title: Text('Kingdom Wealth Part ${i + 1}', style: const TextStyle(fontSize: 12)), trailing: ElevatedButton(onPressed: () => playBook('Part ${i + 1}'), style: ElevatedButton.styleFrom(backgroundColor: isBookPlaying? Colors.green : Colors.orange), child: Text(isBookPlaying? 'Stop' : 'Play')))));

  Widget chatView() => Column(children: [
    Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: chatMsgs.length, itemBuilder: (_, i) => Align(alignment: chatMsgs[i]['user'] == 'You'? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: chatMsgs[i]['user'] == 'You'? Colors.deepPurple : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10)), child: Text(chatMsgs[i]['msg']!, style: const TextStyle(fontSize: 12)))))),
    Padding(padding: const EdgeInsets.all(8), child: Row(children: [
      IconButton(icon: const Icon(Icons.mic, color: Colors.orange), onPressed: () async { final uri = Uri.parse('https://wa.me/2340000000000?text=Voice'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }),
      Expanded(child: TextField(controller: chatCtrl, decoration: InputDecoration(hintText: 'Type prayer...', filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
      IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: () { if (chatCtrl.text.isEmpty) return; setState(() { chatMsgs.add({'user': 'You', 'msg': chatCtrl.text}); chatMsgs.add({'user': 'Pastor Chris', 'msg': 'Praying: ${chatCtrl.text} 🙏'}); }); chatCtrl.clear(); }),
    ])),
  ]);

  Widget partnersView() => ListView(padding: const EdgeInsets.all(16), children: [
    Center(child: logo(70, 70)), const SizedBox(height: 10),
    Card(color: const Color(0xFF141414), child: ListTile(title: const Text('Bronze ₦5k'), onTap: () async { final uri = Uri.parse('https://paystack.com/pay/megaoverflow'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); })),
    Card(color: const Color(0xFF141414), child: ListTile(title: const Text('Gold ₦100k'), onTap: () async { final uri = Uri.parse('https://paystack.com/pay/megaoverflow'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); })),
  ]);

  Widget volunteerView() => Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    logo(60, 60),
    const SizedBox(height: 12),
    TextField(controller: volName, decoration: InputDecoration(labelText: 'Name', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 10),
    TextField(controller: volPhone, decoration: InputDecoration(labelText: 'Phone', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 15),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri = Uri.parse('https://wa.me/2340000000000?text=${Uri.encodeComponent("Volunteer: ${volName.text}")}'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple), child: const Text('Submit'))),
  ]));

  Widget testimonyView() => Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    logo(60, 60),
    TextField(controller: testName, decoration: InputDecoration(labelText: 'Name', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 10),
    TextField(controller: testMsg, maxLines: 4, decoration: InputDecoration(labelText: 'Testimony', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 15),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri = Uri.parse('mailto:gcmega1@gmail.com?subject=Testimony&body=${Uri.encodeComponent(testMsg.text)}'); if (await canLaunchUrl(uri)) await launchUrl(uri); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple), child: const Text('Submit'))),
  ]));

  Widget aboutView() => ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(12)), child: const Text('Mega Overflow Radio - Background Play + Bluetooth + Mute + Volume + Timer + Bible Search', style: TextStyle(color: Colors.white)))]);

  Widget miniPlayer() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))),
      child: Column(children: [
        Slider(value: volume, min: 0, max: 1, activeColor: Colors.deepPurple, inactiveColor: Colors.white12, onChanged: setVolume),
        Row(children: [
          logo(36, 36),
          const SizedBox(width: 8),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          IconButton(icon: Icon(isMuted? Icons.volume_off : Icons.volume_up, size: 20), onPressed: toggleMute),
          isLoading? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(onPressed: togglePlay, icon: Icon(isPlaying? Icons.pause_circle_filled : Icons.play_circle_filled, size: 34, color: Colors.deepPurple)),
        ]),
      ]),
    );
  }
}
