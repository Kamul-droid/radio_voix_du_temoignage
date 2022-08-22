import 'dart:ui';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:radio_voix_du_temoignage/common.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fade_out_particle/fade_out_particle.dart';


Future<void> main()  async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voix du Temoignage',

      home: MyHomePage(title: 'Voix du Temoignage'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;


  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  late AudioPlayer _player ;
  final bool _disapear = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {

        });
    // Try to load audio from a source and catch any errors.
    try {
      // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac

      await _player.setAudioSource(AudioSource.uri(Uri.parse("https://listen.radioking.com/radio/489683/stream/546491"),
      tag: MediaItem(id: '1', title: "Témoignage")));
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  @override
  void dispose() {
    ambiguate(WidgetsBinding.instance)!.removeObserver(this);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
              (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));




  @override
  Widget build(BuildContext context) {

    return Container(

      // decoration: const BoxDecoration(
      //   image: DecorationImage(
      //       image: AssetImage('assets/images/vt_backgrd.png'),
      //       fit: BoxFit.cover)),


      child: Scaffold(
        backgroundColor:  Color.alphaBlend(Colors.white,Colors.greenAccent),

        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(padding: EdgeInsets.all(1)),
              Align(

                alignment: Alignment.bottomCenter,

                child: Image.asset('assets/images/icons/vt_logo.png'),
              ),

              Padding(padding: EdgeInsets.all(10)),

              // Display play/pause button and volume/speed sliders.
              ControlButtons(_player),
              FadeOutParticle(
                  disappear: _disapear,
                  curve: Curves.bounceIn,
                  duration: const Duration(milliseconds: 20000) ,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_sharp,
                        size: 16,
                        color: Theme.of(context).primaryColorDark,
                      ),
                      const SizedBox( width: 8),

                      Text('Bienvenue sur la voix du témoignage',
                        style: Theme.of(context).textTheme.headline6,),
                    ],
                  )),

              Align(
                alignment: Alignment(0, 5),

                child: Image.asset('assets/images/icons/mix.png',fit: BoxFit.contain,
                ),


              ),


            ],
          ),
        ),
      ),

    );


  }

}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        /// This StreamBuilder rebuilds whenever the player state changes, which
        /// includes the playing/paused state and also the
        /// loading/buffering/ready state. Depending on the state we show the
        /// appropriate button or loading indicator.
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 60.0,
                color: Color.fromARGB(255, 236, 28, 6),
                highlightColor: Colors.deepPurple,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                color: Colors.green,
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero),
              );
            }
          },
        ),
        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) =>
              IconButton(
                icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  showSliderDialog(
                    context: context,
                    title: "Adjust speed",
                    divisions: 10,
                    min: 0.5,
                    max: 1.5,
                    value: player.speed,
                    stream: player.speedStream,
                    onChanged: player.setSpeed,
                  );
                },
              ),
        ),
      ],
    );
  }
}
