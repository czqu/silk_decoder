import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silk_decoder/silk_decoder.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Silk V3 Player & Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _ffmpegPath;
  String _status = '请拖拽或选择一个音频文件';
  String? _currentFilePath;
  String? _currentWavPath;

  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadFFmpegPath();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadFFmpegPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ffmpegPath = prefs.getString('ffmpeg_path');
    });
    if (_ffmpegPath == null) {
      _autoDetectFFmpeg();
    }
  }

  Future<void> _saveFFmpegPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ffmpeg_path', path);
    setState(() {
      _ffmpegPath = path;
    });
  }

  Future<void> _autoDetectFFmpeg() async {
    String command = Platform.isWindows ? 'where' : 'which';
    ProcessResult result = await Process.run(command, ['ffmpeg']);
    if (result.exitCode == 0) {
      String path = result.stdout.toString().trim().split('\n').first;
      await _saveFFmpegPath(path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('自动检测到 FFmpeg: $path')),
      );
    }
  }

  Future<void> _pickFFmpegPath() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      await _saveFFmpegPath(result.files.single.path!);
    }
  }

  Future<void> _processFile(String filePath) async {
    if (_ffmpegPath == null || _ffmpegPath!.isEmpty) {
      setState(() {
        _status = '错误: 请先设置 FFmpeg 路径!';
      });
      return;
    }

    setState(() {
      _status = '正在解码...';
      _currentFilePath = filePath;
      _playerState = PlayerState.stopped;
      _duration = Duration.zero;
      _position = Duration.zero;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final pcmPath = p.join(tempDir.path, '${p.basename(filePath)}.pcm');
      final wavPath = p.join(tempDir.path, '${p.basename(filePath)}.wav');

      await decodeSilkFileAsync(filePath,  pcmPath, 24000);
      setState(() => _status = '正在转换为 WAV...');
      await _convertPcmToWav(pcmPath, wavPath);

      await _audioPlayer.setSourceDeviceFile(wavPath);
      await _audioPlayer.resume();
      setState(() {
        _status = '准备就绪: ${p.basename(filePath)}';
        _currentWavPath = wavPath;
      });

    } catch (e) {
      setState(() {
        _status = '处理失败: $e';
      });
    }
  }

  Future<void> _convertPcmToWav(String pcmPath, String wavPath) async {
    final result = await Process.run(_ffmpegPath!, [
      '-y',           // Overwrite output file if it exists
      '-f', 's16le',  // Format of the input file (signed 16-bit little-endian PCM)
      '-ar', '24000', // Audio sample rate of the input file
      '-ac', '1',     // Audio channels of the input file (1 for mono)
      '-i', pcmPath,  // Input file path
      '-c:a', 'pcm_s16le', // Explicitly set the audio codec for the output to pcm_s16le
      wavPath,        // Output file path
    ]);
    if (result.exitCode != 0) {
      throw Exception('FFmpeg 转换失败: ${result.stderr}');
    }
  }

  Future<void> _exportFile(String format) async {
    if (_currentFilePath == null) return;

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: '请选择保存位置:',
      fileName: '${p.basenameWithoutExtension(_currentFilePath!)}.$format',
    );

    if (outputFile == null) return;


    setState(() => _status = '正在导出为 $format...');

    try {
      final tempDir = await getTemporaryDirectory();
      final pcmPath = p.join(tempDir.path, '${p.basename(_currentFilePath!)}.pcm');
      await File(pcmPath).exists();
      final result = await Process.run(_ffmpegPath!, [
        '-y',
        '-f', 's16le',
        '-ar', '24000',
        '-ac', '1',
        '-i', pcmPath,
        outputFile,
      ]);

      if (result.exitCode == 0) {
        setState(() => _status = '导出成功: $outputFile');
      } else {
        throw Exception('FFmpeg 导出失败: ${result.stderr}');
      }
    } catch (e) {
      setState(() => _status = '导出失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Silk 播放和转换工具'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [

            _buildDropZone(),
            const SizedBox(height: 20),
            if (_currentFilePath != null) _buildPlayerControls(),
            const SizedBox(height: 20),
            _buildInfoZone(),

          ],
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    return DropTarget(
      onDragDone: (details) {
        final path = details.files.first.path;
        if (['.slk', '.aud', '.amr'].any((ext) => path.endsWith(ext))) {
          _processFile(path);
        }
      },
      child: InkWell(
        onTap: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['slk', 'aud', 'amr'],
          );
          if (result != null) {
            _processFile(result.files.single.path!);
          }
        },
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600, style: BorderStyle.solid, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 50),
                SizedBox(height: 10),
                Text('拖拽文件到这里或点击选择'),
                Text('.slk, .aud, .amr', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Slider(
              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() + 0.1),
              max: _duration.inSeconds.toDouble() + 0.1,
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position)),
                Text(_formatDuration(_duration)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_playerState == PlayerState.playing ? Icons.pause : Icons.play_arrow),
                  iconSize: 48,
                  onPressed: _currentWavPath == null ? null : () {
                    if (_playerState == PlayerState.playing) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.resume();
                    }
                  },
                ),
                const SizedBox(width: 20),
                PopupMenuButton<String>(
                  onSelected: _exportFile,
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'wav', child: Text('导出为 WAV')),
                    const PopupMenuItem<String>(value: 'mp3', child: Text('导出为 MP3')),
                    const PopupMenuItem<String>(value: 'm4a', child: Text('导出为 M4A (AAC)')),
                  ],
                  child: const Row(
                    children: [
                      Icon(Icons.save_alt),
                      SizedBox(width: 8),
                      Text('导出'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FFmpeg 路径:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(_ffmpegPath ?? '未设置'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _autoDetectFFmpeg, child: const Text('自动检测')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _pickFFmpegPath, child: const Text('手动选择')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildInfoZone() {
    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withAlpha((255 * 0.5).round()),
        ),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          _status,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}