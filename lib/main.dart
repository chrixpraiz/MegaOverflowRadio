import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.megaoverflow.radio',
      androidNotificationChannelName: 'Mega Overflow Radio',
      androidNotificationOngoing: true,
    );
  } catch(e){ print('bg init fail $e'); }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const RadioPage(),
      theme: ThemeData.dark(),
    );
  }
}

class RadioPage extends StatefulWidget { const RadioPage({super.key}); @override State<RadioPage> createState()=> _RadioPageState(); }

class _RadioPageState extends State<RadioPage> with SingleTickerProviderStateMixin {
  final player = AudioPlayer();
  late AnimationController anim;
  bool playing=false, loading=false;
  String title="Mega Overflow Radio - Ready";
  String artist="Faith Comes By Hearing";
  int listeners=0;
  List tracks=[];

  @override void initState(){ super.initState(); anim=AnimationController(vsync:this, duration: const Duration(seconds:4)); start(); }
  Future<void> start() async {
    try{
      final s = await AudioSession.instance;
      await s.configure(const AudioSessionConfiguration.music());
    }catch(_){}
    fetchMeta();
    Timer.periodic(const Duration(seconds:15), (_)=> fetchMeta());
    fetchHistory();
  }
  Future<void> fetchMeta() async {
    try{
      final r = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/now_playing/')).timeout(const Duration(seconds:5));
      if(r.statusCode==200){ var j=json.decode(r.body); if(mounted) setState((){ title=j['title']??title; artist=j['artist']??artist; listeners=j['listeners']??0; }); }
    }catch(_){}
  }
  Future<void> fetchHistory() async {
    try{
      final r = await http.get(Uri.parse('https://www.radiojar.com/api/stations/kks1y4wm7s8uv/tracks/?limit=100')).timeout(const Duration(seconds:5));
      if(r.statusCode==200){ var j=json.decode(r.body); if(mounted) setState(()=> tracks = j is List? j : j['items']??[]); }
    }catch(_){}
  }
  Future<void> toggle() async {
    if(playing){ await player.pause(); setState(()=>playing=false); anim.stop(); return; }
    setState(()=>loading=true);
    try{
      await player.setAudioSource(AudioSource.uri(Uri.parse('https://stream.radiojar.com/kks1y4wm7s8uv'), tag: MediaItem(id:'1', title:'Mega Overflow Radio', artist:'LIVE')));
      await player.play();
      setState((){playing=true; loading=false;});
      anim.repeat();
    }catch(e){
      setState(()=>loading=false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stream error: $e')));
    }
  }
  @override void dispose(){ anim.dispose(); player.dispose(); super.dispose(); }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text('Radio LIVE ($listeners)')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
          RotationTransition(turns: anim, child: Container(width:200,height:200, decoration: const BoxDecoration(shape:BoxShape.circle, color:Colors.deepPurple), child: const Icon(Icons.radio, size:100, color:Colors.white))),
          const SizedBox(height:30),
          Padding(padding: const EdgeInsets.symmetric(horizontal:20), child: Text(title, textAlign:TextAlign.center, style: const TextStyle(color:Colors.white, fontSize:20, fontWeight:FontWeight.bold))),
          Text(artist, style: const TextStyle(color:Colors.purpleAccent)),
          const SizedBox(height:30),
          Padding(padding: const EdgeInsets.all(20), child: GestureDetector(onTap: toggle, child: Container(height:60, width:double.infinity, decoration: BoxDecoration(color: playing?Colors.red:Colors.white, borderRadius:BorderRadius.circular(30)), child: Center(child: loading? const CircularProgressIndicator(): Text(playing? 'STOP':'LISTEN LIVE', style: TextStyle(color: playing?Colors.white:Colors.black, fontWeight:FontWeight.bold, fontSize:20)))))),
        ]),
      ),
    );
  }
}