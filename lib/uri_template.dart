// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri_template;

import 'dart:math' as math;
import 'dart:utf';

import 'src/encoding.dart';

final _exprRegex = new RegExp(r'{('
    r'([+#./;?&]?)' // optional operator
    r'((?:\w|[%.])+(?:(?::\d+)|\*)?' // first varspec
    r'(?:,(?:\w|[%.])+(?:(?::\d+)|\*)?)*)' // rest varspecs
    r')}');
final _literalVerifier = new RegExp(r'[{}]');

const _OPERATORS = r'+#./;?&';

// TODO(justinfagnani): write real, non-spec, documentation.
/**
 * An implementation of [RFC 6570][rfc6570] URI Templates.
 *
 * [rfc6570]: http://tools.ietf.org/html/rfc6570
 *
 * A URI Template is a string describing a range of URIs that can be created
 * through variable expansion.
 *
 * URI Templates provide a number of different ways that variables can be
 * expanded into parts of a URI, suitable for usage as multi-segment paths,
 * path segments, query strings, fragment identifiers and more.
 *
 * Examples:
 *
 *  * http://example.com/~{username}/
 *  * http://example.com/dictionary/{term:1}/{term}
 *  * http://example.com/search{?q,lang}
 *
 * See the RFC for more details.
 */
class UriTemplate {
  final String template;

  UriTemplate(this.template);

  /**
   *  Expands the template into a URI according to the rules specified in RFC
   *  6570. Throws a [ParseException] if the template is invalid.
   */
  String expand(Map<String, Object> variables) =>
    template.splitMapJoin(_exprRegex,
        onMatch: (Match match) {
          var expr = match.group(3);
          var op = match.group(2);
          var separator = ['', '+', '#'].contains(op) ? ','
              : (op == '?') ? '&' : op;
          bool formStyle = [';', '?', '&'].contains(op);
          bool allowReserved = ['+', '#'].contains(op);
          StringBuffer sb = new StringBuffer();

          var result = expr.split(',').map((String varspec) {
            var varname = varspec;
            int prefixLength = 0;
            int prefixModIndex = varspec.lastIndexOf(':');
            if (prefixModIndex != -1) {
              varname = varspec.substring(0, prefixModIndex);
              prefixLength = int.parse(varspec.substring(prefixModIndex + 1));
            }
            bool explode = varspec[varspec.length - 1] == '*';
            if (explode) {
              varname = varspec.substring(0, varspec.length - 1);
            }
            var itemSeparator = explode ? separator : ',';

            var value = variables[varname];
            var str;
            if (value is Iterable) {
              if (prefixLength != 0) throw new ParseException(expr);
              if (value.isNotEmpty) {
                if (explode && formStyle) {
                  itemSeparator = '$itemSeparator$varname=';
                }
                str = value.map((i) => _encode('$i', allowReserved))
                    .join(itemSeparator);
                if (formStyle) str = '$varname=$str';
              }
            } else if (value is Map) {
              if (prefixLength != 0) throw new ParseException(expr);
              if (value.isNotEmpty) {
                var kvSeparator = explode ? '=' : ',';
                str = value.keys.map((k) => _encode(k) + kvSeparator +
                    _encode('${value[k]}', allowReserved)
                ).join(itemSeparator);
                if (formStyle && !explode) str = '$varname=$str';
              }
            } else if (value != null) {
              if (prefixLength > 0 && prefixLength < value.length) {
                str = '$value'.substring(0, prefixLength);
              } else {
                str = '$value';
              }
              str = _encode(str, allowReserved);
              if (formStyle) {
                str = (str.isEmpty && op == ';') ? varname : '$varname=$str';
              }
            }
            return str;
          }).where((e) => e != null);
          if (result.length > 0 && !(op == '' || op == '+')) sb.write(op);
          return sb..writeAll(result, separator)..toString();
        },
        onNonMatch: (String nonMatch) {
          if (_literalVerifier.hasMatch(nonMatch)) {
            throw new ParseException(nonMatch);
          }
          return _encode(nonMatch, true);
        });
}

String _encode(String s, [bool allowReserved = false]) {
  var table = allowReserved ? reservedTable : unreservedTable;
  return pctEncode(s, table, allowPctTriplets: allowReserved);
}

class ParseException implements Exception {
  final String message;
  ParseException(this.message);
  String toString() => "ParseException: $message";
}
