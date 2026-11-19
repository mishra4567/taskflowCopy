// services/spend/receipt_scanner.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_layout.dart';

// A scanned receipt as rows, ready for PaymentTextParser.parseRows.
class ScannedReceipt {
  const ScannedReceipt(this.rows);
  final List<ReceiptRow> rows;
}

// Reads the text out of an image on the phone (nothing is uploaded),
// WORD by word with each word's position, then rebuilds the rows.
// Latin script covers English-language receipts.
Future<ScannedReceipt> scanReceiptImage(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    final words = <PositionedWord>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final box = element.boundingBox;
          words.add(
            PositionedWord(
              element.text,
              left: box.left,
              top: box.top,
              right: box.right,
              bottom: box.bottom,
            ),
          );
        }
      }
    }
    return ScannedReceipt(groupWordsIntoRows(words));
  } finally {
    await recognizer.close();
  }
}
