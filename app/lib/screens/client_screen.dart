import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/websocket_service.dart';

class ClientScreen extends StatefulWidget {
  final String? initialRoom;
  const ClientScreen({super.key, this.initialRoom});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  late WebSocketService _wsService;
  late bool _isScanning;
  final TextEditingController _roomController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isScanning = true;
    _wsService = Provider.of<WebSocketService>(context, listen: false);
    
    if (widget.initialRoom != null) {
      _roomController.text = widget.initialRoom!;
    }
  }

  @override
  void dispose() {
    _wsService.leaveRoom();
    super.dispose();
  }

  void _formatDurationHelper() {}

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      String scannedValue = barcodes.first.rawValue!;
      String roomId = scannedValue;
      
      // If the QR code is a URL, extract the 'room' parameter
      if (scannedValue.startsWith('http')) {
        try {
          Uri uri = Uri.parse(scannedValue);
          if (uri.queryParameters.containsKey('room')) {
            roomId = uri.queryParameters['room']!;
          }
        } catch (e) {
          print("Error parsing URI: $e");
        }
      }
      
      setState(() => _isScanning = false);
      Provider.of<WebSocketService>(context, listen: false).joinRoom(roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsService = Provider.of<WebSocketService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isScanning ? 'Scan QR Code' : 'Client Room'),
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
          child: _isScanning
              ? _buildScanner()
              : wsService.currentRoom == null
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                  : _buildSyncedPlayer(wsService),
        ),
      ),
    );
  }


  Widget _buildScanner() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Point your camera at the Host\'s QR code or enter Room ID.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          // Text Input Fallback
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roomController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter Room ID (e.g. A1B2C3)',
                      hintStyle: const TextStyle(color: Colors.white30),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_roomController.text.isNotEmpty) {
                      setState(() => _isScanning = false);
                      Provider.of<WebSocketService>(context, listen: false).joinRoom(_roomController.text.toUpperCase());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                  child: const Text('Join'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
            ),
            child: const Center(
              child: Text(
                'Tip: You can also use your phone\'s native camera app to scan the Host\'s QR code. It will automatically open the browser and join the room!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSyncedPlayer(WebSocketService wsService) {
    bool isPlaying = wsService.status == 'playing';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Connected to Party!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E5FF),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Room ID: ${wsService.currentRoom}',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 50),
        // Glassmorphism Player Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
              )
            ],
          ),
          child: Column(
            children: [
              // Spinning CD dummy
              AnimatedRotation(
                turns: isPlaying ? 1.0 : 0.0,
                duration: const Duration(seconds: 2),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFFFF007F), Color(0xFF00E5FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF007F).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Song Title',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Synced with Host',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              // Progress bar and timestamps
              StreamBuilder<Duration>(
                stream: wsService.audioPlayer.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = wsService.audioPlayer.duration ?? const Duration(seconds: 1);
                  double sliderVal = position.inSeconds.toDouble();
                  double maxVal = duration.inSeconds.toDouble();
                  if (sliderVal > maxVal) sliderVal = maxVal;
                  
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: const Color(0xFF00E5FF),
                          inactiveTrackColor: Colors.white.withOpacity(0.2),
                          thumbShape: SliderComponentShape.noThumb, // Client can't seek
                        ),
                        child: Slider(
                          value: sliderVal,
                          min: 0,
                          max: maxVal == 0 ? 1 : maxVal,
                          onChanged: null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              ),
              const SizedBox(height: 20),
              // Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isPlaying ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.play_arrow : Icons.pause,
                      color: isPlaying ? const Color(0xFF00E5FF) : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPlaying ? 'PLAYING' : 'PAUSED',
                      style: TextStyle(
                        color: isPlaying ? const Color(0xFF00E5FF) : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
