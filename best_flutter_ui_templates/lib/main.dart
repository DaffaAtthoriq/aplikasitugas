import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Audio Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black, // Berdasarkan image_2.png
        primaryColor: const Color(0xFF2C5528), // Hijau tua berdasarkan image.png
      ),
      home: const LibraryScreen(),
    );
  }
}

// ==========================================
// STATE MANAGEMENT (PROVIDER)
// ==========================================
class AudioProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  
  List<File> _songs = [];
  File? _currentSong;
  Set<String> _favoritePaths = {}; // Menyimpan path lagu favorit
  String? _selectedDirectory;
  
  // Metadata Mock/Deteksi Dasar
  String _audioOutput = "Speaker Ponsel"; // Placeholder deteksi output
  
  List<File> get songs => _songs;
  File? get currentSong => _currentSong;
  AudioPlayer get player => _player;
  String get audioOutput => _audioOutput;

  bool isFavorite(String path) => _favoritePaths.contains(path);

  void toggleFavorite(String path) {
    if (_favoritePaths.contains(path)) {
      _favoritePaths.remove(path);
    } else {
      _favoritePaths.add(path);
    }
    notifyListeners();
  }

  Future<void> addDirectory() async {
    var status = await Permission.storage.request();
    // Tambahan untuk Android 13+
    var audioStatus = await Permission.audio.request();
    
    if (status.isGranted || audioStatus.isGranted) {
      String? result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _selectedDirectory = result;
        await rescanLibrary();
      }
    }
  }

  Future<void> rescanLibrary() async {
    if (_selectedDirectory == null) return;
    
    final dir = Directory(_selectedDirectory!);
    List<File> audioFiles = [];
    
    if (dir.existsSync()) {
      final entities = dir.listSync(recursive: true);
      for (var entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (['.mp3', '.flac', '.wav', '.m4a', '.aac'].contains(ext)) {
            audioFiles.add(entity);
          }
        }
      }
    }
    
    _songs = audioFiles;
    notifyListeners();
  }

  Future<void> playSong(File song) async {
    try {
      _currentSong = song;
      notifyListeners();
      await _player.setAudioSource(AudioSource.uri(Uri.file(song.path)));
      _player.play();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  void playNext() {
    if (_songs.isEmpty || _currentSong == null) return;
    int currentIndex = _songs.indexOf(_currentSong!);
    if (currentIndex < _songs.length - 1) {
      playSong(_songs[currentIndex + 1]);
    }
  }

  void playPrevious() {
    if (_songs.isEmpty || _currentSong == null) return;
    int currentIndex = _songs.indexOf(_currentSong!);
    if (currentIndex > 0) {
      playSong(_songs[currentIndex - 1]);
    }
  }
}

// ==========================================
// LAYAR KOLEKSI (LIBRARY SCREEN)
// ==========================================
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Koleksi Kamu', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Add Directory',
            onPressed: () => provider.addDirectory(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan Library',
            onPressed: () => provider.rescanLibrary(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: provider.songs.isEmpty
                ? const Center(child: Text("Belum ada lagu. Tambahkan direktori musik."))
                : ListView.builder(
                    itemCount: provider.songs.length,
                    itemBuilder: (context, index) {
                      final song = provider.songs[index];
                      final isPlaying = provider.currentSong?.path == song.path;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPlaying ? Colors.white.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12), // Rounded edges modern
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[800],
                              child: const Icon(Icons.music_note, color: Colors.white54),
                            ),
                          ),
                          title: Text(
                            p.basenameWithoutExtension(song.path),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPlaying ? Colors.greenAccent : Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            "Local Audio • ${p.extension(song.path).toUpperCase().replaceAll('.', '')}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          onTap: () => provider.playSong(song),
                        ),
                      );
                    },
                  ),
          ),
          if (provider.currentSong != null) const MiniPlayer(),
        ],
      ),
    );
  }
}

// ==========================================
// MINI PLAYER (BOTTOM BAR)
// ==========================================
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioProvider>();
    final song = provider.currentSong;

    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NowPlayingScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C5528), // Warna hijau tua
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                color: Colors.white24,
                child: const Icon(Icons.music_note, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.basenameWithoutExtension(song.path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            StreamBuilder<PlayerState>(
              stream: provider.player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final playing = playerState?.playing ?? false;
                return IconButton(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: () {
                    if (playing) {
                      provider.player.pause();
                    } else {
                      provider.player.play();
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// LAYAR PUTAR SEKARANG (NOW PLAYING SCREEN)
// ==========================================
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AudioProvider>();
    final song = provider.currentSong;
    final ext = song != null ? p.extension(song.path).toUpperCase().replaceAll('.', '') : 'MP3';

    // Mock Metadata Teknis berdasarkan format
    final String frequency = (ext == 'FLAC' || ext == 'WAV') ? "48.0 kHz" : "44.1 kHz";
    final String bitrate = (ext == 'FLAC' || ext == 'WAV') ? "1411 kbps" : "320 kbps";

    return Scaffold(
      backgroundColor: const Color(0xFF2C5528), // Palet hijau tua
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Playlist Saat Ini", // Diganti sesuai instruksi
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Gambar Seni Album Besar
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        )
                      ],
                    ),
                    child: const Icon(Icons.album, size: 150, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Info Lagu & Tombol Ekstra
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song != null ? p.basenameWithoutExtension(song.path) : "Memuat...",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Artis Tidak Diketahui", // Metadata artist mock
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.white70),
                    onPressed: () {}, // Mempertahankan simbol 'X'
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                    onPressed: () {}, // Mempertahankan simbol '+'
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Panel Detail Audio (Fitur Baru)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "$frequency | $bitrate | $ext",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {}, // Placeholder Bitperfect
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                    child: const Text(
                      "Mode Bitperfect",
                      style: TextStyle(fontSize: 12, color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Output Audio Detection (Fitur Baru)
              Row(
                children: [
                  const Icon(Icons.speaker_group_outlined, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    provider.audioOutput,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // Slider Seek (Dimodifikasi: Lebih besar dan tebal)
              StreamBuilder<Duration>(
                stream: provider.player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = provider.player.duration ?? Duration.zero;

                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8.0, // Dibuat jauh lebih tebal
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0), // Thumb lebih besar
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          min: 0.0,
                          max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                          value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                          onChanged: (value) {
                            provider.player.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            Text("-${_formatDuration(duration - position)}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const Spacer(),

              // Kontrol Pemutaran (Diperluas)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle, color: Colors.white),
                    onPressed: () {}, // Logic shuffle bisa ditambahkan ke provider
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                    onPressed: () => provider.playPrevious(),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: provider.player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final playing = playerState?.playing ?? false;
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 48,
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black),
                          onPressed: () {
                            if (playing) provider.player.pause();
                            else provider.player.play();
                          },
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                    onPressed: () => provider.playNext(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.repeat, color: Colors.white),
                    onPressed: () {}, // Logic repeat
                  ),
                  // Ikon Favorit menggantikan Equalizer/Share
                  IconButton(
                    icon: Icon(
                      song != null && provider.isFavorite(song.path) 
                          ? Icons.favorite 
                          : Icons.favorite_border,
                      color: song != null && provider.isFavorite(song.path) 
                          ? Colors.red 
                          : Colors.white,
                    ),
                    onPressed: () {
                      if (song != null) provider.toggleFavorite(song.path);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
