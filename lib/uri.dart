// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri;

import 'package:quiver/collection.dart';
import 'package:quiver/core.dart';
import 'package:quiver/pattern.dart';

import 'src/encoding.dart';

part 'uri_template.dart';
part 'uri_parser.dart';

/**
 * An interface for objects that match [Uri]s
 */
abstract class UriPattern {

  /**
   * Returns `true` if [uri] is matched by this pattern.
   */
  bool matches(Uri uri) => match(uri) != null;

  /**
   * Returns a [UriMatch] describing the match if [uri] is matched by this
   * pattern.
   */
  UriMatch match(Uri uri);

}

/**
 * The result of a [UriPattern.match] call.
 */
class UriMatch {

  /**
   * The pattern used to match against [input].
   */
  final UriPattern pattern;

  /**
   * The Uri on which the match was computed.
   */
  final Uri input;

  /**
   * A map of parameters parsed by the [UriPattern] that produced this match.
   */
  final Map<String, String> parameters;

  /**
   * The remaining parts of the input after the match. This is [UriPattern]
   * implementation-specific, but should typically include the rest of the path
   * if matched as a prefix, and recognized query parameters.
   */
  final Uri rest;

  UriMatch(this.pattern, this.input, this.parameters, this.rest);

  String toString() => 'UriMatch(pattern: $pattern input: $input '
      'parameters: $parameters rest: $rest)';

  bool operator ==(o) =>
      o is UriMatch &&
      pattern == o.pattern &&
      input == o.input &&
      mapsEqual(parameters, o.parameters) &&
      rest == o.rest;

  int get hashCode => hash4(pattern, input, parameters.toString(), rest);
}

/**
 * A mutable holder for incrementally building [Uri]s.
 */
class UriBuilder {
  String fragment = '';
  String host = '';
  String path = '';
  int port = 0;
  Map<String, String> queryParameters = <String, String>{};
  String scheme;
  String userInfo;

  Uri build() => new Uri(
      fragment: fragment,
      host: host,
      path: path,
      port: port,
      queryParameters: queryParameters,
      scheme: scheme,
      userInfo: userInfo);
}
