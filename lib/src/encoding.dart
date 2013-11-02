// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri_template.encoding;

import 'package:utf/utf.dart' show codepointsToUtf8;

const int _PERCENT = 0x25;
const int _ZERO = 0x30;
const int _NINE = 0x39;
const int _UPPER_CASE_A = 0x41;
const int _UPPER_CASE_F = 0x46;
const int _LOWER_CASE_A = 0x61;
const int _LOWER_CASE_F = 0x66;

// Tables of char-codes organized as a bit vector of 128 bits where
// each bit indicate whether a character code on the 0-127 needs to
// be escaped or not.

// The unreserved characters of RFC 3986.
const unreservedTable = const [
              //             LSB            MSB
              //              |              |
    0x0000,   // 0x00 - 0x0f  0000000000000000
    0x0000,   // 0x10 - 0x1f  0000000000000000
              //                           -.
    0x6000,   // 0x20 - 0x2f  0000000000000110
              //              0123456789
    0x03ff,   // 0x30 - 0x3f  1111111111000000
              //               ABCDEFGHIJKLMNO
    0xfffe,   // 0x40 - 0x4f  0111111111111111
              //              PQRSTUVWXYZ    _
    0x87ff,   // 0x50 - 0x5f  1111111111100001
              //               abcdefghijklmno
    0xfffe,   // 0x60 - 0x6f  0111111111111111
              //              pqrstuvwxyz   ~
    0x47ff];  // 0x70 - 0x7f  1111111111100010

// Table of reserved characters
const reservedTable = const [
              //             LSB            MSB
              //              |              |
    0x0000,   // 0x00 - 0x0f  0000000000000000
    0x0000,   // 0x10 - 0x1f  0000000000000000
              //               ! #$ &'()*+,-./
    0xffda,   // 0x20 - 0x2f  0101101111111111
              //              0123456789:; = ?
    0xafff,   // 0x30 - 0x3f  1111111111110101
              //              @ABCDEFGHIJKLMNO
    0xffff,   // 0x40 - 0x4f  1111111111111111
              //              PQRSTUVWXYZ[ ] _
    0xafff,   // 0x50 - 0x5f  1111111111110101
              //               abcdefghijklmno
    0xfffe,   // 0x60 - 0x6f  0111111111111111
              //              pqrstuvwxyz   ~
    0x47ff];  // 0x70 - 0x7f  1111111111100010

/**
 * Copied from dart.core.Uri and modified to preserve pct-encoded triplets and
 * remove '+' encoding.
 *
 * This is the internal implementation of JavaScript's encodeURI function.
 * It encodes all characters in the string [text] except for those
 * that appear in [canonicalTable], and returns the escaped string.
 */
String pctEncode(String text, List<int> canonicalTable,
                 {bool allowPctTriplets: false}) {
  byteToHex(int v) {
    final String hex = '0123456789ABCDEF';
    return '%${hex[v >> 4]}${hex[v & 0x0f]}';
  }

  isHex(int ch) => (ch >= _ZERO && ch <= _NINE) ||
      (ch >= _UPPER_CASE_A && ch <= _UPPER_CASE_F) ||
      (ch >= _LOWER_CASE_A && ch <= _LOWER_CASE_F);

  isPctTriplet(int ch, int i) {
    if (ch == _PERCENT && (i + 2 < text.length)) {
      var t1 = text.codeUnitAt(i + 1);
      var t2 = text.codeUnitAt(i + 2);
      return isHex(t1) && isHex(t2);
    }
    return false;
  }

  var result = new StringBuffer();
  for (int i = 0; i < text.length; i++) {
    int ch = text.codeUnitAt(i);
    if (allowPctTriplets && isPctTriplet(ch, i)) {
      result.write(text.substring(i, i + 3));
      i += 2;
    } else if (ch < 128 &&
        ((canonicalTable[ch >> 4] & (1 << (ch & 0x0f))) != 0)) {
      result.write(text[i]);
    } else {
      if (ch >= 0xD800 && ch < 0xDC00) {
        // Low surrogate. We expect a next char high surrogate.
        ++i;
        int nextCh = text.length == i ? 0 : text.codeUnitAt(i);
        if (nextCh >= 0xDC00 && nextCh < 0xE000) {
          // convert the pair to a U+10000 codepoint
          ch = 0x10000 + ((ch - 0xD800) << 10) + (nextCh - 0xDC00);
        } else {
          throw new ArgumentError('Malformed URI');
        }
      }
      for (int codepoint in codepointsToUtf8([ch])) {
        result.write(byteToHex(codepoint));
      }
    }
  }
  return result.toString();
}
