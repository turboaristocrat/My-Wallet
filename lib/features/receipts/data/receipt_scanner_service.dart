import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class ParsedReceipt {
  final String merchantName;
  final double totalAmount;
  final DateTime date;
  final String? suggestedCategory;
  final List<String> lineItems;
  final double confidence;

  const ParsedReceipt({
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    this.suggestedCategory,
    this.lineItems = const [],
    this.confidence = 0.85,
  });
}

class ReceiptScannerService {
  final AppDatabase _db;
  ReceiptScannerService(this._db);

  /// Heuristic & Regex OCR parser that converts raw scanned receipt text into structured data
  ParsedReceipt parseReceiptText(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String detectedMerchant = 'Scanned Merchant';
    double detectedAmount = 0.0;
    DateTime detectedDate = DateTime.now();
    String? suggestedCategory;
    final List<String> items = [];

    // 1. Detect Merchant Name (usually among first 3 non-empty lines)
    for (int i = 0; i < lines.length && i < 3; i++) {
      final line = lines[i];
      if (!RegExp(r'tax|invoice|bill|receipt|gst|welcome|tel|phone|date',
              caseSensitive: false)
          .hasMatch(line)) {
        if (line.length >= 3 && line.length <= 40) {
          detectedMerchant = line;
          break;
        }
      }
    }

    // 2. Detect Total Amount
    final totalRegexes = [
      RegExp(r'(?:total|grand\s*total|net\s*amount|bill\s*amount|paid\s*amount|amount\s*paid)[:\s]*(?:rs\.?|inr|₹)?\s*([\d,]+\.?\d*)',
          caseSensitive: false),
      RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d*)', caseSensitive: false),
    ];

    for (final line in lines) {
      for (final regex in totalRegexes) {
        final match = regex.firstMatch(line);
        if (match != null) {
          final cleanStr = match.group(1)!.replaceAll(',', '');
          final val = double.tryParse(cleanStr);
          if (val != null && val > detectedAmount) {
            detectedAmount = val;
          }
        }
      }
    }

    // 3. Detect Date
    final dateRegex = RegExp(
        r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})|(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})');
    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        try {
          if (match.group(1) != null) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);
            if (year < 100) year += 2000;
            detectedDate = DateTime(year, month, day);
            break;
          } else if (match.group(4) != null) {
            final year = int.parse(match.group(4)!);
            final month = int.parse(match.group(5)!);
            final day = int.parse(match.group(6)!);
            detectedDate = DateTime(year, month, day);
            break;
          }
        } catch (_) {}
      }
    }

    // 4. Category Prediction based on text
    final textLower = ocrText.toLowerCase();
    if (textLower.contains('restaurant') ||
        textLower.contains('cafe') ||
        textLower.contains('coffee') ||
        textLower.contains('burger') ||
        textLower.contains('pizza') ||
        textLower.contains('dining') ||
        textLower.contains('food')) {
      suggestedCategory = 'Food & Dining';
    } else if (textLower.contains('supermarket') ||
        textLower.contains('grocery') ||
        textLower.contains('mart') ||
        textLower.contains('retail') ||
        textLower.contains('store')) {
      suggestedCategory = 'Groceries';
    } else if (textLower.contains('fuel') ||
        textLower.contains('petrol') ||
        textLower.contains('diesel') ||
        textLower.contains('shell') ||
        textLower.contains('hp') ||
        textLower.contains('ioc')) {
      suggestedCategory = 'Transport & Fuel';
    } else if (textLower.contains('medical') ||
        textLower.contains('pharmacy') ||
        textLower.contains('apollo') ||
        textLower.contains('hospital')) {
      suggestedCategory = 'Healthcare';
    } else {
      suggestedCategory = 'Shopping';
    }

    // 5. Line items extract
    for (final line in lines) {
      if (RegExp(r'\b\d+\.?\d{2}\b').hasMatch(line) &&
          !line.toLowerCase().contains('total')) {
        items.add(line);
      }
    }

    return ParsedReceipt(
      merchantName: detectedMerchant,
      totalAmount: detectedAmount,
      date: detectedDate,
      suggestedCategory: suggestedCategory,
      lineItems: items,
      confidence: detectedAmount > 0 ? 0.90 : 0.60,
    );
  }

  /// Attach a scanned receipt image to a transaction
  Future<String> saveReceiptAttachment({
    required String transactionId,
    required String filePath,
    List<String>? parsedItems,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.receiptAttachments).insert(
          ReceiptAttachmentsCompanion.insert(
            id: Value(id),
            transactionId: transactionId,
            filePath: filePath,
            parsedItemsJson: Value(
              parsedItems != null && parsedItems.isNotEmpty
                  ? jsonEncode(parsedItems)
                  : null,
            ),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Watch receipt attachments for a given transaction
  Stream<List<ReceiptAttachment>> watchAttachments(String transactionId) {
    return (_db.select(_db.receiptAttachments)
          ..where((t) => t.transactionId.equals(transactionId))
          ..where((t) => t.isDeleted.equals(false)))
        .watch();
  }
}

// --- Provider ---

final receiptScannerServiceProvider = Provider<ReceiptScannerService>((ref) {
  return ReceiptScannerService(ref.watch(databaseProvider));
});
