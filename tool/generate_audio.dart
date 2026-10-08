import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  Directory('assets/sounds').createSync(recursive: true);

  writeWav('assets/sounds/chime.wav', generateChime());
  writeWav('assets/sounds/success.wav', generateSuccess());
  writeWav('assets/sounds/nudge.wav', generateNudge());
  writeWav('assets/sounds/click.wav', generateClick());

  // ignore: avoid_print
  print('Audio files generated successfully in assets/sounds/');
}

List<double> generateChime() {
  const sampleRate = 44100;
  const duration = 1.2;
  final numSamples = (sampleRate * duration).toInt();
  final samples = List<double>.filled(numSamples, 0.0);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    // 528 Hz fundamental + 660 Hz third + 1056 Hz octave
    final tone1 = sin(2 * pi * 528 * t) * exp(-2.5 * t);
    final tone2 = sin(2 * pi * 660 * t) * exp(-3.0 * t) * 0.6;
    final tone3 = sin(2 * pi * 1056 * t) * exp(-4.5 * t) * 0.3;
    samples[i] = (tone1 + tone2 + tone3) * 0.5;
  }
  return samples;
}

List<double> generateSuccess() {
  const sampleRate = 44100;
  const duration = 1.4;
  final numSamples = (sampleRate * duration).toInt();
  final samples = List<double>.filled(numSamples, 0.0);

  // Arpeggio notes: C5 (523Hz), E5 (659Hz), G5 (784Hz), C6 (1046Hz)
  final notes = [
    {'time': 0.0, 'freq': 523.25, 'dur': 0.8},
    {'time': 0.15, 'freq': 659.25, 'dur': 0.8},
    {'time': 0.30, 'freq': 783.99, 'dur': 0.9},
    {'time': 0.45, 'freq': 1046.50, 'dur': 1.0},
  ];

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double sample = 0.0;
    for (final note in notes) {
      final startTime = note['time'] as double;
      final freq = note['freq'] as double;
      final dur = note['dur'] as double;
      if (t >= startTime && t < startTime + dur) {
        final relT = t - startTime;
        final env = exp(-3.5 * relT);
        sample += sin(2 * pi * freq * relT) * env * 0.3;
      }
    }
    samples[i] = sample.clamp(-1.0, 1.0);
  }
  return samples;
}

List<double> generateNudge() {
  const sampleRate = 44100;
  const duration = 0.9;
  final numSamples = (sampleRate * duration).toInt();
  final samples = List<double>.filled(numSamples, 0.0);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double sample = 0.0;
    if (t < 0.35) {
      sample = sin(2 * pi * 440 * t) * exp(-4.0 * t) * 0.4;
    } else if (t >= 0.25) {
      final relT = t - 0.25;
      sample += sin(2 * pi * 554.37 * relT) * exp(-3.5 * relT) * 0.45;
    }
    samples[i] = sample.clamp(-1.0, 1.0);
  }
  return samples;
}

List<double> generateClick() {
  const sampleRate = 44100;
  const duration = 0.05;
  final numSamples = (sampleRate * duration).toInt();
  final samples = List<double>.filled(numSamples, 0.0);

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    samples[i] = sin(2 * pi * 1200 * t) * exp(-120.0 * t) * 0.3;
  }
  return samples;
}

void writeWav(String path, List<double> samples) {
  const sampleRate = 44100;
  const numChannels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  final blockAlign = numChannels * (bitsPerSample ~/ 8);
  final subChunk2Size = samples.length * (bitsPerSample ~/ 8);
  final chunkSize = 36 + subChunk2Size;

  final buffer = BytesBuilder();

  // RIFF header
  buffer.add('RIFF'.codeUnits);
  buffer.add(_int32(chunkSize));
  buffer.add('WAVE'.codeUnits);

  // fmt subchunk
  buffer.add('fmt '.codeUnits);
  buffer.add(_int32(16)); // SubChunk1Size (16 for PCM)
  buffer.add(_int16(1)); // AudioFormat (1 = PCM)
  buffer.add(_int16(numChannels));
  buffer.add(_int32(sampleRate));
  buffer.add(_int32(byteRate));
  buffer.add(_int16(blockAlign));
  buffer.add(_int16(bitsPerSample));

  // data subchunk
  buffer.add('data'.codeUnits);
  buffer.add(_int32(subChunk2Size));

  // Audio samples in 16-bit PCM
  for (final sample in samples) {
    final clamped = sample.clamp(-1.0, 1.0);
    final intVal = (clamped * 32767).toInt();
    buffer.add(_int16(intVal));
  }

  File(path).writeAsBytesSync(buffer.toBytes());
}

List<int> _int16(int value) {
  return [value & 0xFF, (value >> 8) & 0xFF];
}

List<int> _int32(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}
