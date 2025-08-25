# Silk Decoder

A Dart library for decoding SILK audio files to PCM format using native bindings, with asynchronous support to avoid blocking the main thread.

# Basic Example

```dart
import 'package:your_package/silk_decoder.dart';

void main() async {
  // Decode a SILK file to PCM
  final inputPath = 'path/to/input.silk';
  final outputPath = 'path/to/output.pcm';
  final sampleRate = 44100; // Desired output sample rate

  try {
    final result = await decodeSilkFileAsync(inputPath, outputPath, sampleRate);
    if (result == 0) {
      print('Decoding successful! PCM file saved to $outputPath');
    } else {
      print('Decoding failed with error code: $result');
    }
  } catch (e) {
    print('Error during decoding: $e');
  }
}
```

## API Reference

### `decodeSilkFileAsync`

```dart
Future<int> decodeSilkFileAsync(
  String inputPath,
  String outputPath,
  int sampleRate,
)
```

#### Parameters:

- `inputPath`: Path to the input SILK file (String)
- `outputPath`: Path where the output PCM file will be saved (String)
- `sampleRate`: Desired sample rate for the output PCM (int)

#### Returns:

A `Future<int>` that completes with:

- `0`: Decoding successful
- Non-zero: Error code (specific 含义 depends on native implementation)

## Acknowledgments

- Original work associated with [kn007's blog](https://kn007.net/).
- Copyright holder: Karl Chen (2020).

This project uses the silk-v3-decoder library in compliance with its MIT License, acknowledging the contributions of the original authors and maintainers.