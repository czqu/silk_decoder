import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'silk_decoder_bindings_generated.dart';

/// Asynchronously decodes a SILK file to PCM format.
///
/// This function executes the native `decode_silk_file` function on a separate
/// isolate to prevent blocking the main UI thread.
///
/// Returns a future that completes with the exit code from the native function
/// (0 for success).
Future<int> decodeSilkFileAsync(
  String inputPath,
  String outputPath,
  int sampleRate,
) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextDecodeRequestId++;
  final request = _DecodeRequest(requestId, inputPath, outputPath, sampleRate);
  final completer = Completer<int>();
  _decodeRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

const String _libName = 'silk_decoder';

/// The dynamic library in which the symbols for [SilkDecoderBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final SilkDecoderBindings _bindings = SilkDecoderBindings(_dylib);

/// A request to decode a SILK file.
class _DecodeRequest {
  final int id;
  final String inputPath;
  final String outputPath;
  final int sampleRate;

  const _DecodeRequest(
    this.id,
    this.inputPath,
    this.outputPath,
    this.sampleRate,
  );
}

/// A response with the result of the decoding operation.
class _DecodeResponse {
  final int id;
  final int result; // 0 for success

  const _DecodeResponse(this.id, this.result);
}

/// Counter for decode requests.
int _nextDecodeRequestId = 0;

/// Mapping for pending decode requests.
final Map<int, Completer<int>> _decodeRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  final Completer<SendPort> completer = Completer<SendPort>();

  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        completer.complete(data);
        return;
      }
      if (data is _DecodeResponse) {
        final Completer<int> completer = _decodeRequests[data.id]!;
        _decodeRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }

      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is _DecodeRequest) {
          // Convert Dart strings to C strings (Pointer<Utf8>).
          final inputPath = data.inputPath.toNativeUtf8();
          final outputPath = data.outputPath.toNativeUtf8();

          final int result = _bindings.decode_silk_file(
            inputPath as Pointer<Char>,
            outputPath as Pointer<Char>,
            data.sampleRate,
          );


          malloc.free(inputPath);
          malloc.free(outputPath);

          final response = _DecodeResponse(data.id, result);
          sendPort.send(response);
          return;
        }

        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  return completer.future;
}();
