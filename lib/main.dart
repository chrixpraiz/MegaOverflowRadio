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

class MegaOverflowApp extends StatelessWidget {
  const MegaOverflowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MegaOverflow Radio',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
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
  final AudioPlayer player = AudioPlayer();
  bool isPlaying = false;
  bool isLoading = false;
  String title = "Mega Overflow Radio";
  String artist = "Word, Worship and Wealth";
  String cover = "";
  List<dynamic> history = [];
  late AnimationController vinyl;
  BannerAd? bannerAd;
  bool isAdLoaded = false;

  final List<String> tabNames = [
    'Radio', 'Recently Played', 'Schedule', 'Sermons',
    'E-Books & Library', 'Audio Bible', 'Audiobooks',
    'Chat & Voice Altar', 'Partner With Us', 'Volunteer', 'Testimony', 'About Us'
  ];

  final List<IconData> tabIcons = [
    Icons.radio, Icons.history, Icons.calendar_month, Icons.mic,
    Icons.menu_book, Icons.headphones, Icons.album,
    Icons.chat_bubble, Icons.handshake, Icons.groups, Icons.favorite, Icons.info
  ];

  final List<Map<String, String>> events = [
    {'title': 'Morning Overflow', 'day': 'Mon - Fri', 'time': '5:00 AM - 7:00 AM', 'host': 'Pastor Chris Praiz'},
    {'title': 'Worship Encounter', 'day': 'Mon - Fri', 'time': '12:00 PM - 1:00 PM', 'host': 'Min. Damitha'},
    {'title': 'Wealth Wisdom', 'day': 'Wed & Fri', 'time': '7:00 PM - 8:30 PM', 'host': 'Pastor Chris'},
    {'title': 'Sunday Prophetic Service', 'day': 'Sundays', 'time': '8:00 AM - 11:30 AM', 'host': 'Pastor Chris Praiz'},
  ];

  final List<Map<String, String>> sermons = [
    {'title': 'The Overflow Anointing', 'preacher': 'Pastor Chris Praiz', 'duration': '45:23'},
    {'title': 'Wealth Transfer', 'preacher': 'Pastor Chris Praiz', 'duration': '38:12'},
    {'title': 'Worship That Opens Heaven', 'preacher': 'Min. Damitha', 'duration': '52:10'},
    {'title': 'Faith For Overflow', 'preacher': 'Pastor Chris Praiz', 'duration': '41:15'},
  ];

  final List<String> bibleBooks = [
    'Genesis','Exodus','Leviticus','Numbers','Deuteronomy','Joshua','Judges','Ruth','1 Samuel','2 Samuel',
    '1 Kings','2 Kings','1 Chronicles','2 Chronicles','Ezra','Nehemiah','Esther','Job','Psalms','Proverbs',
    'Ecclesiastes','Song of Solomon','Isaiah','Jeremiah','Lamentations','Ezekiel','Daniel','Hosea','Joel',
    'Amos','Obadiah','Jonah','Micah','Nahum','Habakkuk','Zephaniah','Haggai','Zechariah','Malachi',
    'Matthew','Mark','Luke','John','Acts','Romans','1 Corinthians','2 Corinthians','Galatians','Ephesians',
    'Philippians','Colossians','1 Thessalonians','2 Thessalonians','1 Timothy','2 Timothy','Titus','Philemon',
    'Hebrews','James','1 Peter','2 Peter','1 John','2 John','3 John','Jude','Revelation'
  ];

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
      bannerAd = BannerAd(
        adUnitId: 'ca-app-pub-3940256099942544/6300978111',
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => isAdLoaded = true),
          onAdFailedToLoad: (_, __) => setState(() => isAdLoaded = false),
        ),
      )..load();
    } catch (_) {}
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          title = data['track']?? data['title']?? title;
          artist = data['artist']?? artist;
          cover = data['thumb']?? cover;
        });
      }
      final his = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/'));
      if (his.statusCode == 200) {
        setState(() => history = json.decode(his.body));
      }
    } catch (_) {}
  }

  Future<void> togglePlay() async {
    if (isPlaying) {
      await player.pause();
      setState(() => isPlaying = false);
      vinyl.stop();
      return;
    }
    setState(() => isLoading = true);
    const urls = [
      'https://stream.radiojar.com/kks1y4wm7s8uv',
      'https://stream.radiojar.com/kks1y4wm7s8uv.mp3',
    ];
    for (var u in urls) {
      try {
        await player.setAudioSource(AudioSource.uri(Uri.parse(u)));
        await player.play();
        setState(() { isPlaying = true; isLoading = false; });
        vinyl.repeat();
        return;
      } catch (_) { continue; }
    }
    setState(() => isLoading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream offline, try again')));
  }

  @override
  void dispose() {
    player.dispose();
    vinyl.dispose();
    bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: Drawer(
        backgroundColor: const Color(0xFF111111),
        child: Column(
          children: [
            Container(
              height: 170,
              width: double.infinity,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)])),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 75, height: 75,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset('assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.mic, size: 40, color: Colors.deepPurple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('MEGA OVERFLOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                    const Text('Word • Worship • Wealth', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: tabNames.length,
                itemBuilder: (c, i) => ListTile(
                  leading: Icon(tabIcons[i], color: currentView == i? Colors.orange : Colors.purpleAccent, size: 20),
                  title: Text(tabNames[i], style: TextStyle(fontSize: 12.5, fontWeight: currentView == i? FontWeight.bold : FontWeight.normal, color: currentView == i? Colors.white : Colors.white70)),
                  selected: currentView == i,
                  selectedTileColor: Colors.purple.withOpacity(0.15),
                  onTap: () { setState(() => currentView = i); Navigator.pop(context); },
                ),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text(tabNames[currentView], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          Container(margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: const Center(child: Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: currentView,
              children: [
                _radioView(), _historyView(), _scheduleView(), _sermonsView(),
                _ebooksView(), _bibleView(), _audiobooksView(), _chatView(),
                _partnersView(), _volunteerView(), _testimonyView(), _aboutView(),
              ],
            ),
          ),
          if (isAdLoaded && bannerAd!= null) Container(color: Colors.black, height: bannerAd!.size.height.toDouble(), width: double.infinity, child: AdWidget(ad: bannerAd!)),
          _miniPlayer(),
        ],
      ),
    );
  }

  Widget _radioView() {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A0A0A), Color(0xFF000000)])),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            RotationTransition(
              turns: vinyl,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF141414), border: Border.all(color: const Color(0xFF222222), width: 10), boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 30)]),
                child: Center(
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 5)),
                    child: ClipOval(
                      child: cover.isNotEmpty
                         ? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.orange, child: const Icon(Icons.mic))))
                          : Image.asset('assets/images/logo.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.orange, child: const Icon(Icons.mic, color: Colors.white, size: 40))),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: isPlaying? Colors.green : Colors.orange, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(isPlaying? 'ON AIR NOW' : 'READY TO STREAM', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('320 KBPS HD', style: TextStyle(fontSize: 9, color: Colors.orange))),
                  ]),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center, maxLines: 2),
                  const SizedBox(height: 6),
                  Text(artist, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoading? null : togglePlay,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      icon: isLoading? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isPlaying? Icons.pause : Icons.play_arrow, size: 28),
                      label: Text(isPlaying? 'Pause Radio' : 'Listen Live', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyView() {
    if (history.isEmpty) return const Center(child: Text('Loading history...', style: TextStyle(color: Colors.white54)));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: history.length, itemBuilder: (_, i) {
      final t = history[i];
      return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(t['thumb']?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.purple, child: const Icon(Icons.music_note)))), title: Text(t['track']?? t['title']?? 'Track', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1), subtitle: Text(t['artist']?? 'Mega Overflow', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)), trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.orange), onPressed: togglePlay)));
    });
  }

  Widget _scheduleView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: events.length, itemBuilder: (_, i) {
    final e = events[i];
    return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: ListTile(leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month, color: Colors.orange)), title: Text(e['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text('${e['day']} • ${e['time']}\nHost: ${e['host']}', style: const TextStyle(fontSize: 10, color: Colors.white60)), isThreeLine: true));
  });

  Widget _sermonsView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: sermons.length, itemBuilder: (_, i) {
    final s = sermons[i];
    return Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(width: 55, height: 55, color: Colors.deepPurple.withOpacity(0.4), child: const Icon(Icons.mic, color: Colors.white))), title: Text(s['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text('${s['preacher']} • ${s['duration']}', style: const TextStyle(fontSize: 10)), trailing: const Icon(Icons.play_arrow, color: Colors.deepPurple)));
  });

  Widget _ebooksView() => GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: 6, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: Column(children: [Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), child: Container(color: Colors.orange.withOpacity(0.3), width: double.infinity, child: const Icon(Icons.menu_book, size: 50, color: Colors.orange)))), Padding(padding: const EdgeInsets.all(8), child: Column(children: const [Text('Overflow Principles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center), Text('Chris Praiz', style: TextStyle(fontSize: 9, color: Colors.purpleAccent))]))])));

  Widget _bibleView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: bibleBooks.length, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.3), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))), title: Text(bibleBooks[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), trailing: const Icon(Icons.headphones, color: Colors.orange, size: 20), onTap: () {})));

  Widget _audiobooksView() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: 5, itemBuilder: (_, i) => Card(color: const Color(0xFF141414), child: ListTile(leading: Container(width: 50, height: 50, color: Colors.purple.withOpacity(0.2), child: const Icon(Icons.album, color: Colors.purpleAccent)), title: Text('Kingdom Wealth - Part ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: const Text('Audiobook • 2h 14m', style: TextStyle(fontSize: 10, color: Colors.white54)), trailing: ElevatedButton(onPressed: togglePlay, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(60, 30)), child: const Text('Play', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold))))));

  Widget _chatView() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Text('🙏 Welcome to Voice Altar - Share your prayer request, we pray 24/7', style: TextStyle(fontSize: 12))),
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12)), child: const Text('Pastor Chris: We are praying with you! Your overflow is coming! Stay connected.', style: TextStyle(fontSize: 12, color: Colors.purpleAccent))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(decoration: InputDecoration(hintText: 'Type prayer request...', filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: () {}))),
        ],
      ),
    );
  }

  Widget _partnersView() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/images/logo.png', width: 80, height: 80, errorBuilder: (_, __, ___) => const Icon(Icons.handshake, size: 60, color: Colors.orange))),
    const SizedBox(height: 12), const Text('Partner With Mega Overflow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Support 24/7 gospel broadcast worldwide', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 20),
    _tier('Bronze Partner', '₦5,000/month', Colors.brown), _tier('Silver Partner', '₦20,000/month', Colors.grey), _tier('Gold Partner', '₦100,000/month', Colors.amber),
    const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri = Uri.parse('https://paystack.com/pay/megaoverflow'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Become a Partner', style: TextStyle(fontWeight: FontWeight.bold)))),
  ]));

  Widget _tier(String name, String price, Color c) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Row(children: [Icon(Icons.star, color: c), const SizedBox(width: 10), Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Spacer(), Text(price, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12))]));

  Widget _volunteerView() => Padding(padding: const EdgeInsets.all(16), child: ListView(children: [
    const Icon(Icons.groups, size: 60, color: Colors.deepPurple), const SizedBox(height: 12), const Text('Join Our Team', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center), const SizedBox(height: 16),
    TextField(decoration: _inputDec('Full Name')), const SizedBox(height: 12), TextField(decoration: _inputDec('Phone / WhatsApp')), const SizedBox(height: 12),
    DropdownButtonFormField<String>(items: const [DropdownMenuItem(value: 'Media', child: Text('Media Team')), DropdownMenuItem(value: 'Prayer', child: Text('Prayer Team')), DropdownMenuItem(value: 'Outreach', child: Text('Outreach Team')), DropdownMenuItem(value: 'Technical', child: Text('Technical Team'))], onChanged: (_) {}, decoration: _inputDec('Department')),
    const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Apply to Volunteer'))),
  ]));

  Widget _testimonyView() => SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
    const Icon(Icons.favorite, size: 50, color: Colors.orange), const SizedBox(height: 12), const Text('Share Your Praise Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 16),
    TextField(decoration: _inputDec('Your Name')), const SizedBox(height: 12), TextField(decoration: _inputDec('Location')), const SizedBox(height: 12), TextField(decoration: _inputDec('Your Testimony'), maxLines: 5),
    const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async { final uri = Uri.parse('mailto:gcmega1@gmail.com?subject=Testimony - Mega Overflow Radio'); if (await canLaunchUrl(uri)) await launchUrl(uri); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Submit Testimony'))),
  ]));

  Widget _aboutView() => ListView(padding: const EdgeInsets.all(16), children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Image.asset('assets/images/logo.png', width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.mic, color: Colors.white)), const SizedBox(width: 10), const Text('Our Divine Mandate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))]), const SizedBox(height: 10), const Text('Mega Overflow Radio is a premier 24/7 internet radio station dedicated to delivering transformative gospel broadcasts: Word, Worship, and Wealth encounters.', style: TextStyle(color: Colors.white, fontSize: 12.5))])),
    const SizedBox(height: 12), _aboutCard('Vision', 'To saturate the airwaves with the overflow of God\'s presence and power, reaching every home worldwide.'), _aboutCard('Mission', '24/7 Word, Worship, and Wealth to every nation through quality broadcasting.'),
    _aboutCard('Contact', 'Email: gcmega1@gmail.com\nPhone: +234 000 000 0000\nLocation: Akwa Ibom, Nigeria\nStation: Mega Overflow Radio'),
  ]);

  Widget _aboutCard(String t, String d) => Card(color: const Color(0xFF141414), margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)), const SizedBox(height: 6), Text(d, style: const TextStyle(color: Colors.white70, fontSize: 12))])));

  InputDecoration _inputDec(String label) => InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFF141414), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

  Widget _miniPlayer() => Container(height: 66, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [
    ClipRRect(borderRadius: BorderRadius.circular(6), child: cover.isNotEmpty? Image.network(cover, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.png', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.orange, child: const Icon(Icons.mic, size: 20)))) : Image.asset('assets/images/logo.png', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 44, height: 44, color: Colors.orange, child: const Icon(Icons.mic, size: 20)))),
    const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.purpleAccent, fontSize: 9))])),
    isLoading? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(onPressed: togglePlay, icon: Icon(isPlaying? Icons.pause_circle_filled : Icons.play_circle_filled, size: 42, color: Colors.deepPurple)),
  ]));
}
