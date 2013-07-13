// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri_template;

import 'dart:math' as math;
import 'dart:utf';

import 'src/encoding.dart';
import 'src/utils.dart';

final _exprRegex = new RegExp(r'{('
    r'([+#./;?&]?)' // optional operator
    r'((?:\w|[%.])+(?:(?::\d+)|\*)?' // first varspec
    r'(?:,(?:\w|[%.])+(?:(?::\d+)|\*)?)*)' // rest varspecs
    r')}');
final _literalVerifier = new RegExp(r'[{}]');
final _simpleExprRegex = new RegExp(r'(?:\w|[%.,])+');
final _varspecRegex = new RegExp(r'^((?:\w|[%.])+)((?::\d+)|(?:\*))?$');

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
  final List _parts;

  // parsing helpers, setup in _prepareParsing()
  RegExp _pathRegex;
  List<String> _pathVariables;
  List<String> _queryVariables;
  List<String> _fragmentVariables;

  UriTemplate(String template)
      : template = template, _parts = _compile(template);

  static List _compile(String template) {
    List parts = [];
    template.splitMapJoin(_exprRegex,
        onMatch: (match) => parts.add(match),
        onNonMatch: (String nonMatch) {
          if (_literalVerifier.hasMatch(nonMatch)) {
            throw new ParseException(nonMatch);
          }
          if (nonMatch.isNotEmpty) parts.add(nonMatch);
        });
    return parts;
  }

  /**
   *  Expands the template into a URI according to the rules specified in RFC
   *  6570. Throws a [ParseException] if the template is invalid.
   */
  String expand(Map<String, Object> variables) {
    StringBuffer sb = new StringBuffer();
    for (var part in _parts) {
      if (part is Match) {
        Match match = part;
        var expr = match.group(3);
        var op = match.group(2);
        var separator = ['', '+', '#'].contains(op) ? ','
            : (op == '?') ? '&' : op;
        bool formStyle = [';', '?', '&'].contains(op);
        bool allowReserved = ['+', '#'].contains(op);

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
        }).where((e) => e != null).toList(growable: false);
        if (result.length > 0) {
          if (!(op == '' || op == '+')) {
            sb.write(op);
          }
          sb.writeAll(result, separator);
        }
      } else {
        sb.write(_encode(part, true));
      }
    }
    return sb.toString();
  }

  // TODO:
  // implement matches()
  Map<String, String> parse(String uriString) {
    _prepareParsing();
    var uri = Uri.parse(uriString);
    var parameters = {};

    if (_pathVariables != null) {
      var match = _pathRegex.firstMatch(uri.path);
      if (match == null) {
        throw new ParseException('$template does not match $uriString');
      }
      int i = 1;
      for (var param in _pathVariables) {
        parameters[param] = match.group(i++);
      }
    }
    if (_queryVariables != null) {
      for (var key in _queryVariables) {
        parameters[key] = uri.queryParameters[key];
      }
    }
    if (_fragmentVariables != null) {
      // assume that fragments with an '=' char are key/value maps
      // parse them forgivingly, and put pairs into a map as the value
      // of the fragment expression's variable
      if (_fragmentVariables.length == 1 && uri.fragment.contains('=')) {
        var map = {};
        var kvPairs = uri.fragment.split(',');
        for (int i = 0; i < kvPairs.length; i++) {
          String kvPair = kvPairs[i];
          var eqIndex = kvPair.indexOf('=');
          if (eqIndex > -1) {
            var key = kvPair.substring(0, eqIndex);
            var value = '';
            // handle key1=,,key2=x
            if (eqIndex == kvPair.length - 1) {
              if (i < kvPairs.length - 1 && kvPairs[i+1] == '') {
                value = ',';
              }
              // else value = '';
            } else {
              value = kvPair.substring(eqIndex + 1);
            }
            map[key] = value;
          }
        }
        parameters[_fragmentVariables.first] = map;
      } else {
        var fragmentValues = uri.fragment.split(',');
        for (var i = 0; i < _fragmentVariables.length; i++) {
          parameters[_fragmentVariables[i]] = fragmentValues[i];
        }
      }
    }
    return parameters;
  }

  // Performs one-time setup for parsing URIs
  // TODO(justin): support explode and prefix modifiers
  // TODO(justin): support more operators
  _prepareParsing() {
    if (_pathRegex != null) return;
    var pattern = _parts.map((part) {
      if (part is Match) {
        Match match = part;
        var expr = match.group(3);
        var op = match.group(2);
        if (op == '' || op == '+') {
          if (_queryVariables != null) {
            throw new ParseException('Query expressions must not appear before '
                'path expressions: $template');
          }
          if (!_simpleExprRegex.hasMatch(expr)) {
            throw new ParseException('Unsupported expression $expr: $template');
          }
          if (_pathVariables == null) _pathVariables = [];
          return expr.split(',').map((varspec) {
            _pathVariables.add(_varspecRegex.firstMatch(varspec).group(1));
            if (op == '') return r'((?:\w|%)+)';
            // ?, #, [,  and ] cannot appear in URI paths
            if (op == '+') return r"((?:\w|[:/@!$&'()*+,;=])+)";
          }).join(',');
        } else if (op == '?') {
          if (_queryVariables != null) throw new ParseException('More than one '
              'query expression found: $template');
          _queryVariables = expr.split(',').map((e) =>
              _varspecRegex.firstMatch(e).group(1)).toList(growable: false);
        } else if (op == '#') {
          if (_pathVariables != null) {
            throw new ParseException('Fragment expressions '
                'must not appear before path expressions: $template');
          }
          if (_fragmentVariables != null) {
            throw new ParseException('More than one fragment expression found: '
                '$template');
          }
          _fragmentVariables = expr.split(',').map((e) =>
              _varspecRegex.firstMatch(e).group(1)).toList(growable: false);
        } else {
          throw new ParseException("Unsupported operation $op: $template");
        }
      } else {
        return '(?:${escapeRegex(part)})';
      }
    }).where((i) => i != null).join('');
    _pathRegex = new RegExp('^$pattern\$');
  }
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
