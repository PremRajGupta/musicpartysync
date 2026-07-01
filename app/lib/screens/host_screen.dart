import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/websocket_service.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late WebSocketService _wsService;
  bool _isUploading = false;
  String _songTitle = 'No Song Selected';

  @override
  void initState() {
    super.initState();
    _wsService = Provider.of<WebSocketService>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wsService.createRoom();
    });
  }

  @override
  void dispose() {
    _wsService.leaveRoom();
    super.dispose();
  }

  Future<void> _pickAndUploadSong() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true, // Need bytes for web
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _isUploading = true;
        _songTitle = result.files.single.name;
      });

      try {
        var request = http.MultipartRequest(
            'POST', Uri.parse('${_wsService.serverHttpUrl}/upload'));
        
        request.files.add(http.MultipartFile.fromBytes(
          'song',
          result.files.single.bytes!,
          filename: result.files.single.name,
        ));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final url = data['url'];
          _wsService.updateSongUrl(url);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song uploaded and synced!')),
          );
        } else {
          print("Upload failed");
        }
      } catch (e) {
        print("Error uploading: $e");
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsService = Provider.of<WebSocketService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: wsService.currentRoom == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Scan to Join',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // QR Code Container (Glassmorphism)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                        ),
                        child: QrImageView(
                          data: '${Uri.base.origin}/?room=${wsService.currentRoom}',
                          version: QrVersions.auto,
                          size: 180.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Room ID: ${wsService.currentRoom}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Pick Song Button
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickAndUploadSong,
                        icon: _isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.music_note),
                        label: Text(_isUploading ? 'Uploading...' : 'Pick & Sync Song'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Player UI
                      _buildPlayerUI(wsService),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPlayerUI(WebSocketService wsService) {
    bool isPlaying = wsService.status == 'playing';
    bool hasSong = wsService.currentSongUrl != null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        children: [
          AnimatedRotation(
            turns: isPlaying ? 1.0 : 0.0,
            duration: const Duration(seconds: 2),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFFF007F), Color(0xFF00E5FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _songTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Progress bar dummy UI updated to actual position
          StreamBuilder<Duration>(
            stream: wsService.audioPlayer.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = wsService.audioPlayer.duration ?? const Duration(seconds: 1);
              double sliderVal = position.inSeconds.toDouble();
              double maxVal = duration.inSeconds.toDouble();
              if (sliderVal > maxVal) sliderVal = maxVal;
              
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: const Color(0xFF00E5FF),
                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: sliderVal,
                  min: 0,
                  max: maxVal == 0 ? 1 : maxVal,
                  onChanged: hasSong ? (val) {
                    wsService.audioPlayer.seek(Duration(seconds: val.toInt()));
                    wsService.syncState(wsService.status, val);
                  } : null,
                ),
              );
            }
          ),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                iconSize: 32,
                onPressed: hasSong ? () {
                  final newPos = (wsService.audioPlayer.position.inSeconds - 10).clamp(0, wsService.audioPlayer.duration?.inSeconds ?? 0);
                  wsService.audioPlayer.seek(Duration(seconds: newPos));
                  wsService.syncState(wsService.status, newPos.toDouble());
                } : null,
              ),
              GestureDetector(
                onTap: hasSong ? () {
                  String newStatus = isPlaying ? 'paused' : 'playing';
                  wsService.syncState(newStatus, wsService.audioPlayer.position.inSeconds.toDouble());
                } : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasSong ? const Color(0xFF00E5FF) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: const Color(0xFF0F172A),
                    size: 40,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                iconSize: 32,
                onPressed: hasSong ? () {
                  final newPos = (wsService.audioPlayer.position.inSeconds + 10).clamp(0, wsService.audioPlayer.duration?.inSeconds ?? 0);
                  wsService.audioPlayer.seek(Duration(seconds: newPos));
                  wsService.syncState(wsService.status, newPos.toDouble());
                } : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
