import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.megaoverflow.radio',
    androidNotificationChannelName: 'Mega Overflow Radio',
    androidNotificationOngoing: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mega Overflow Radio',
      theme: ThemeData.dark(),
      home: const RadioPage(),
    );
  }
}

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});
  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> with SingleTickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  late AnimationController anim;
  bool playing = false;
  bool loading = false;
  String title = 'Mega Overflow Radio';
  String artist = 'LIVE';
  int listeners = 0;
  List tracks = [];

  @override
  void initState() {
    super.initState();
    anim = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    initAudio();
  }

  Future<void> initAudio() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    fetchMeta();
    Timer.periodic(const Duration(seconds: 10), (t) => fetchMeta());
    fetchHistory();
  }

  Future<void> fetchMeta() async {
    try {
      final res = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final j = json.decode(res.body);
        setState(() {
          title = j['title']?.toString()?? title;
          artist = j['artist']?.toString()?? artist;
          listeners = j['listeners']?? 0;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> fetchHistory() async {
    try {
      final res = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/?limit=50')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final j = json.decode(res.body);
        setState(() {
          tracks = j is List? j : (j['items']?? j['tracks']?? []);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> playRadio() async {
    if (playing) {
      await player.pause();
      setState(() => playing = false);
      anim.stop();
      return;
    }
    setState(() => loading = true);
    List<String> urls = [
      'https://stream.radiojar.com/kks1y4wm7s8uv',
      'http://stream.radiojar.com/kks1y4wm7s8uv',
      'https://n0b.radiojar.com/kks1y4wm7s8uv',
    ];
    for (var u in urls) {
      try {
        await player.setAudioSource(AudioSource.uri(Uri.parse(u), tag: MediaItem(id: 'live', title: 'Mega Overflow Radio', artist: 'LIVE')));
        await player.play();
        setState(() {
          playing = true;
          loading = false;
        });
        anim.repeat();
        return;
      } catch (e) {
        print('fail $u $e');
      }
    }
    setState(() => loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream failed, try again')));
    }
  }

  Future<void> playTrack(Map t) async {
    try {
      String url = t['url']?.toString()?? 'https://stream.radiojar.com/kks1y4wm7s8uv';
      setState(() => loading = true);
      await player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await player.play();
      setState(() {
        playing = true;
        loading = false;
        title = t['title']?.toString()?? 'Playing';
        artist = t['artist']?.toString()?? '';
      });
      anim.repeat();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    anim.dispose();
    player.dispose();
    super.dispose();
  }

  Widget logo(double w, double h) {
    return ClipOval(
      child: Image.asset('assets/icon/app_icon.png', width: w, height: h, fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(width: w, height: h, color: Colors.deepPurple, child: const Icon(Icons.radio, color: Colors.white, size: 40))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text('Radio LIVE ($listeners)')),
      drawer: Drawer(
        backgroundColor: const Color(0xFF121212),
        child: ListView(
          children: [
            DrawerHeader(
              child: Column(
                children: [
                  logo(80, 80),
                  const SizedBox(height: 10),
                  const Text('Mega Overflow Radio', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.radio, color: Colors.white),
              title: const Text('Radio', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white),
              title: const Text('Recently Played', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.black,
                  builder: (ctx) => ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (c, i) {
                      var tr = tracks[i] as Map;
                      return ListTile(
                        title: Text(tr['title']?.toString()?? 'Unknown', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(tr['artist']?.toString()?? '', style: const TextStyle(color: Colors.purpleAccent)),
                        trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.orange), onPressed: () => playTrack(tr)),
                      );
                    },
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book, color: Colors.white),
              title: const Text('Audio Bible', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.black,
                  builder: (ctx) => ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (c, i) {
                      var tr = tracks[i] as Map;
                      return ListTile(
                        title: Text(tr['title']?.toString()?? 'Bible', style: const TextStyle(color: Colors.white)),
                        subtitle: const Text('Faith Comes By Hearing', style: TextStyle(color: Colors.purpleAccent)),
                        trailing: IconButton(icon: const Icon(Icons.play_circle, color: Colors.deepPurple), onPressed: () => playTrack(tr)),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Center(
            child: RotationTransition(
              turns: anim,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 6)),
                child: logo(240, 240),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(artist, style: const TextStyle(color: Colors.purpleAccent)),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: playRadio,
                  child: Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(color: playing? Colors.red : Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: Center(
                      child: loading
                         ? const CircularProgressIndicator()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(playing? Icons.stop : Icons.play_arrow, color: playing? Colors.white : Colors.black, size: 30),
                                const SizedBox(width: 10),
                                Text(playing? 'STOP RADIO' : 'LISTEN LIVE', style: TextStyle(color: playing? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
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
}