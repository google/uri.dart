// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri.uri_test;

import 'package:test/test.dart';
import 'package:uri/uri.dart';

void main() {

  group('UriMatch', () {
    test('should implement equals and hashCode', () {
      var match1 = new UriMatch(new TestUriPattern(123), Uri.parse('abc'),
          {'a': 'b'}, Uri.parse('bc'));

      var match2 = new UriMatch(new TestUriPattern(123), Uri.parse('abc'),
          {'a': 'b'}, Uri.parse('bc'));
      expect(match1.hashCode, match2.hashCode);
      expect(match1, match2);

      var match3 = new UriMatch(new TestUriPattern(456), Uri.parse('abc'),
          {'a': 'b'}, Uri.parse('bc'));
      expect(match1.hashCode, isNot(match3.hashCode));
      expect(match1, isNot(match3));

      var match4 = new UriMatch(new TestUriPattern(123), Uri.parse('abd'),
          {'a': 'b'}, Uri.parse('bc'));
      expect(match1.hashCode, isNot(match4.hashCode));
      expect(match1, isNot(match4));

      var match5 = new UriMatch(new TestUriPattern(123), Uri.parse('abc'),
          {'c': 'b'}, Uri.parse('bc'));
      expect(match1.hashCode, isNot(match5.hashCode));
      expect(match1, isNot(match5));

      var match6 = new UriMatch(new TestUriPattern(123), Uri.parse('abc'),
          {'a': 'b'}, Uri.parse('bd'));
      expect(match1.hashCode, isNot(match6.hashCode));
      expect(match1, isNot(match6));

    });
  });
}

class TestUriPattern extends UriPattern {
  final int hashCode;
  TestUriPattern(this.hashCode);
  UriMatch match(Uri uri) => null;
  bool operator ==(o) => hashCode == o.hashCode;
  Uri expand(variables) => null;
}
