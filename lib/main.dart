import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:http/http.dart' as http;

const STATION_ID = 'kks1y4wm7s8uv';
const STREAM_URL = 'https://stream.radiojar.com/kks1y4wm7s8uv';
const STREAM_URL_HTTP = 'http://stream.radiojar.com/kks1y4wm7s8uv';
const META_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/now_playing/';
const HISTORY_URL = 'https://www.radiojar.com/api/stations/$STATION_ID/tracks/?limit=100';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // THIS FIXES THE _audioHandler NOT INITIALIZED ERROR
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.megaoverflow.radio.channel.audio',
    androidNotificationChannelName: 'Mega Overflow Radio',
    androidNotificationOngoing: true,
  );
  runApp(const MegaOverflowApp());
}

class MegaOverflowApp extends StatelessWidget {
  const MegaOverflowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mega Overflow Radio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget { const MainScreen({super.key}); @override State<MainScreen> createState()=>_MainScreenState(); }

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  late AnimationController vinylController;
  bool isPlaying=false, isLoading=false, isMuted=false;
  double volume=1.0;
  String title='UNDERSTANDING THE BLESSEDNESS OF A REVIVAL Pt3';
  String artist='PST. DAVID OYEDEPO JNR.';
  int listeners=0;
  Timer? metaTimer;
  List<dynamic> history=[];

  @override
  void initState(){
    super.initState();
    vinylController=AnimationController(vsync:this, duration: const Duration(seconds:4));
    initAudio();
    fetchMeta(); fetchHistory();
    metaTimer=Timer.periodic(const Duration(seconds:10),(_){fetchMeta();});
  }

  Future<void> initAudio() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> fetchMeta() async {
    try{
      final res=await http.get(Uri.parse(META_URL)).timeout(const Duration(seconds:5));
      if(res.statusCode==200){
        final d=json.decode(res.body);
        setState((){
          title = d['title']??d['track']?['title']??title;
          artist = d['artist']??d['track']?['artist']??artist;
          listeners = d['listeners']??d['current_listeners']??0;
          if(title.isEmpty) title='Faith Comes By Hearing - FCBH';
        });
      }
    }catch(_){}
  }

  Future<void> fetchHistory() async {
    try{
      final res=await http.get(Uri.parse(HISTORY_URL)).timeout(const Duration(seconds:5));
      if(res.statusCode==200){
        final d=json.decode(res.body);
        List list = d is List? d : d['tracks']??d['items']??[];
        setState(()=>history=list);
      }
    }catch(_){}
  }

  Future<String> getFreshUrl() async {
    // Try Radiojar API for token URL
    try{
      final r=await http.get(Uri.parse('https://www.radiojar.com/api/stations/$STATION_ID/'),).timeout(const Duration(seconds:4));
      if(r.statusCode==200){
        var j=json.decode(r.body);
        if(j['stream_url']!=null && (j['stream_url'] as String).isNotEmpty) return j['stream_url'];
        if(j['relays']!=null && j['relays'] is List && j['relays'].isNotEmpty) return j['relays'][0]['url'];
      }
    }catch(_){}
    // Direct fallback - just_audio will follow redirect to n0b.radiojar.com?rj-tok=
    return STREAM_URL;
  }

  Future<void> togglePlay() async {
    if(isPlaying){ await player.pause(); setState(()=>isPlaying=false); vinylController.stop(); return; }
    setState(()=>isLoading=true);
    try{
      String url = await getFreshUrl();
      print('Playing: $url');
      // Try HTTPS first then HTTP
      for(var u in [url, STREAM_URL, STREAM_URL_HTTP, 'https://n0b.radiojar.com/$STATION_ID']){
        try{
          await player.setAudioSource(AudioSource.uri(Uri.parse(u), tag: MediaItem(id:'live', title:title, artist:artist, artUri: Uri.parse('https://i.imgur.com/xxx.png'))),);
          await player.setVolume(isMuted?0:volume);
          await player.play();
          setState((){isPlaying=true; isLoading=false;}); vinylController.repeat(); return;
        }catch(e){ print('Fail $u $e'); continue; }
      }
      throw 'All URLs failed';
    }catch(e){
      setState(()=>isLoading=false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e'), backgroundColor: Colors.red));
    }
  }

  @override void dispose(){ metaTimer?.cancel(); vinylController.dispose(); player.dispose(); super.dispose(); }

  Widget safeLogo(double w, double h, {double radius=24}){
    return ClipRRect(borderRadius: BorderRadius.circular(radius),
      child: Image.asset('assets/icon/app_icon.png', width:w, height:h, fit:BoxFit.cover,
        errorBuilder:(_,__,___)=>Container(width:w,height:h,decoration:BoxDecoration(color:Colors.deepPurple, borderRadius:BorderRadius.circular(radius)), child:const Icon(Icons.radio, color:Colors.white, size:40))
      )
    );
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text('Radio LIVE ($listeners)'), actions: [
        IconButton(icon: Icon(isMuted?Icons.volume_off:Icons.volume_up), onPressed: () async { setState(()=>isMuted=!isMuted); await player.setVolume(isMuted?0:volume); }),
        Container(margin:const EdgeInsets.only(right:12), padding:const EdgeInsets.symmetric(horizontal:12,vertical:6), decoration:BoxDecoration(color:Colors.red, borderRadius:BorderRadius.circular(20)), child: Text('LIVE $listeners', style:const TextStyle(fontWeight:FontWeight.bold))),
      ]),
      drawer: Drawer(backgroundColor:const Color(0xFF121212), child:ListView(children:[
        DrawerHeader(decoration:const BoxDecoration(color:Colors.deepPurple), child:Column(children:[safeLogo(80,80), const SizedBox(height:8), const Text('Mega Overflow Radio', style:TextStyle(color:Colors.white, fontWeight:FontWeight.bold))])),
        ListTile(leading:const Icon(Icons.radio, color:Colors.white), title:const Text('Radio', style:TextStyle(color:Colors.white)), onTap:()=>Navigator.pop(context)),
        ListTile(leading:const Icon(Icons.history, color:Colors.white), title:const Text('Recently Played', style:TextStyle(color:Colors.white)), onTap:(){ Navigator.pop(context); showModalBottomSheet(context:context, backgroundColor:const Color(0xFF121212), builder:(_)=> history.isEmpty? const Center(child:Text('No history', style:TextStyle(color:Colors.white))) : ListView.builder(itemCount:history.length, itemBuilder:(c,i){ var t=history[i]; return ListTile(leading:safeLogo(40,40, radius:8), title:Text(t['title']??'Unknown', style:const TextStyle(color:Colors.white)), subtitle:Text(t['artist']??'', style:const TextStyle(color:Colors.purpleAccent)), trailing: IconButton(icon:const Icon(Icons.play_circle, color:Colors.orange), onPressed:() async { Navigator.pop(context); try{ await player.setAudioSource(AudioSource.uri(Uri.parse(t['url']??STREAM_URL))); await player.play(); setState(()=>isPlaying=true); vinylController.repeat(); }catch(_){} })); })); }),
        ListTile(leading:const Icon(Icons.menu_book, color:Colors.white), title:const Text('Audio Bible', style:TextStyle(color:Colors.white)), onTap:(){
          Navigator.pop(context);
          // Full Audio Bible from your Radiojar library
          showModalBottomSheet(context:context, backgroundColor:const Color(0xFF121212), isScrollControlled:true, builder:(_)=> DraggableScrollableSheet(initialChildSize:0.8, builder:(_,ctrl)=> ListView.builder(controller:ctrl, itemCount:history.length, itemBuilder:(c,i){ var t=history[i]; String ttl=(t['title']??'').toString(); if(!ttl.toLowerCase().contains('genesis') &&!ttl.toLowerCase().contains('psalm') &&!ttl.toLowerCase().contains('luke') &&!ttl.toLowerCase().contains('john') &&!ttl.toLowerCase().contains('numbers') &&!ttl.toLowerCase().contains('ezekiel')) return const SizedBox.shrink(); return ListTile(leading:Container(width:40,height:40,decoration:BoxDecoration(color:Colors.deepPurple.withOpacity(0.3), borderRadius:BorderRadius.circular(8)), child:const Icon(Icons.headphones, color:Colors.orange)), title:Text(ttl, style:const TextStyle(color:Colors.white)), subtitle:Text(t['artist']??'Faith Comes By Hearing', style:const TextStyle(color:Colors.purpleAccent)), trailing:IconButton(icon:const Icon(Icons.play_circle, color:Colors.deepPurple), onPressed:() async { try{ await player.setAudioSource(AudioSource.uri(Uri.parse(t['url']??STREAM_URL))); await player.play(); setState(()=>isPlaying=true); vinylController.repeat(); Navigator.pop(context);}catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Play failed: $e')));} })); })));
        }),
      ])),
      body: Column(children:[
        const SizedBox(height:20),
        Center(child: RotationTransition(turns:vinylController, child: Container(width:260, height:260, decoration:BoxDecoration(shape:BoxShape.circle, border:Border.all(color:Colors.white24, width:8)), child:Center(child:safeLogo(180,180, radius:90))))),
        Padding(padding:const EdgeInsets.all(16), child: Row(children:[const Icon(Icons.volume_down, color:Colors.white), Expanded(child: Slider(value:volume, min:0, max:1, activeColor:Colors.deepPurple, onChanged:(v) async { setState(()=>volume=v); await player.setVolume(isMuted?0:v); })), Text('${(volume*100).toInt()}%', style:const TextStyle(color:Colors.white)), const Icon(Icons.bluetooth, color:Colors.blue)])),
        Expanded(child: Container(margin:const EdgeInsets.all(16), padding:const EdgeInsets.all(16), decoration:BoxDecoration(color:const Color(0xFF1E1E1E), borderRadius:BorderRadius.circular(20)), child: Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[ Row(children:[Container(width:10,height:10,decoration:BoxDecoration(color:isPlaying?Colors.green:Colors.orange, shape:BoxShape.circle)), const SizedBox(width:6), Text(isPlaying?'LIVE NOW':'READY TO STREAM', style:const TextStyle(color:Colors.white70, fontSize:12))]), const Text('320 KBPS HD', style:TextStyle(color:Colors.orange, fontSize:11))]),
          const SizedBox(height:16),
          Text(title, textAlign:TextAlign.center, style:const TextStyle(color:Colors.white, fontSize:22, fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          Text(artist, style:const TextStyle(color:Colors.purpleAccent, fontWeight:FontWeight.bold)),
          const SizedBox(height:20),
          GestureDetector(onTap:togglePlay, child: Container(height:56, decoration:BoxDecoration(color: isPlaying?Colors.red: Colors.white, borderRadius:BorderRadius.circular(30)), child: Center(child: isLoading? const CircularProgressIndicator() : Row(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(isPlaying?Icons.stop:Icons.play_arrow, color:isPlaying?Colors.white:Colors.black), const SizedBox(width:8), Text(isPlaying?'Stop Radio':'Listen Live ($listeners Online)', style:TextStyle(color:isPlaying?Colors.white:Colors.black, fontWeight:FontWeight.bold))])))),
        ]))),
        Container(color:const Color(0xFF121212), padding:const EdgeInsets.all(12), child: Row(children:[safeLogo(50,50, radius:8), const SizedBox(width:10), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text(title, maxLines:1, overflow:TextOverflow.ellipsis, style:const TextStyle(color:Colors.white, fontWeight:FontWeight.bold)), Text('$artist • $listeners Online', style:const TextStyle(color:Colors.purpleAccent, fontSize:12))])), isLoading? const SizedBox(width:24,height:24, child:CircularProgressIndicator(strokeWidth:2)): IconButton(icon:Icon(isPlaying?Icons.pause_circle:Icons.play_circle, size:40, color:Colors.white), onPressed:togglePlay)])),
      ]),
    );
  }
}