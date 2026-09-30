import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, themeMode: ThemeMode.dark, darkTheme: ThemeData.dark(), home: const RadioScreen());
}

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});
  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> with SingleTickerProviderStateMixin {
  final player = AudioPlayer();
  bool isPlaying = false;
  String title = "Mega Overflow Radio";
  String artist = "Word, Worship and Wealth";
  String cover = "";
  List history = [];
  late AnimationController vinyl;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    vinyl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    vinyl.stop();
    fetchMeta();
    Timer.periodic(const Duration(seconds: 20), (_) => fetchMeta());
  }

  Future<void> fetchMeta() async {
    try {
      final r = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body);
        setState(() { title = d['track']??title; artist = d['artist']??artist; cover = d['thumb']??""; });
      }
      final h = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/'));
      if (h.statusCode == 200) setState(() => history = json.decode(h.body));
    } catch(_){}
  }

  Future<void> toggle() async {
    if (isPlaying) { await player.pause(); setState(() => isPlaying = false); vinyl.stop(); return; }
    try {
      await player.setAudioSource(AudioSource.uri(Uri.parse('https://stream.radiojar.com/kks1y4wm7s8uv')));
      await player.play();
      setState(() => isPlaying = true); vinyl.repeat();
    } catch(e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error $e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Radio','History','Schedule','Sermons','E-Books','Bible','Audiobooks','Chat','Partners','Volunteer','Testimony','About'];
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: Drawer(backgroundColor: const Color(0xFF111111), child: ListView(children: [const DrawerHeader(child: Text('MEGA OVERFLOW RADIO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20))), ...List.generate(tabs.length, (i) => ListTile(title: Text(tabs[i]), selected: tab==i, onTap: (){ setState(()=> tab=i); Navigator.pop(context);} )) ])),
      appBar: AppBar(title: Text(tabs[tab]), backgroundColor: const Color(0xFF111111), actions: [Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)), child: const Text('LIVE', style: TextStyle(fontSize: 11)))]),
      body: tab==0? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        RotationTransition(turns: vinyl, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF141414), border: Border.all(width: 8, color: Colors.black)), child: Center(child: ClipOval(child: cover.isNotEmpty? Image.network(cover, width: 110, height: 110, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(width:110,height:110,color: Colors.orange)) : Container(width:110,height:110,color: Colors.orange, child: const Icon(Icons.mic, size: 50)))))),
        const SizedBox(height: 30),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        Text(artist, style: const TextStyle(color: Colors.purpleAccent)),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: toggle, icon: Icon(isPlaying? Icons.pause: Icons.play_arrow), label: Text(isPlaying? 'Pause':'Listen Live'), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16))),
      ])) : tab==1? ListView.builder(padding: const EdgeInsets.all(12), itemCount: history.length, itemBuilder: (_,i){ final t=history[i]; return Card(color: const Color(0xFF141414), child: ListTile(leading: Image.network(t['thumb']??'', width: 50, height: 50, errorBuilder: (_,__,___)=> Container(width:50,height:50,color: Colors.purple)), title: Text(t['track']??''), subtitle: Text(t['artist']??'', style: const TextStyle(color: Colors.purpleAccent)))); }) : Center(child: Text('${tabs[tab]} Coming Soon', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      bottomNavigationBar: Container(height: 70, color: const Color(0xFF121212), padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text(artist, maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.purpleAccent))])), IconButton(onPressed: toggle, icon: Icon(isPlaying? Icons.pause_circle: Icons.play_circle, size: 45, color: Colors.deepPurple))]) ),
    );
  }
}
