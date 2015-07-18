// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri.template;

import 'dart:collection' show UnmodifiableListView;

import 'package:quiver/core.dart' show firstNonNull;
import 'package:quiver/pattern.dart' show escapeRegex;

import 'encoding.dart';
import 'uri_builder.dart';
import 'uri_pattern.dart';

final _exprRegex = new RegExp(r'{('
    r'([+#./;?&]?)' // optional operator
    r'((?:\w|[%.])+(?:(?::\d+)|\*)?' // first varspec
    r'(?:,(?:\w|[%.])+(?:(?::\d+)|\*)?)*)' // rest varspecs
    r')}');
final _literalVerifier = new RegExp(r'[{}]');
final _simpleExprRegex = new RegExp(r'(?:\w|[%.,])+');
final _varspecRegex = new RegExp(r'^((?:\w|[%.])+)((?::\d+)|(?:\*))?$');
final _fragmentOrQueryRegex = new RegExp(r'([#?])');
const _OPERATORS = r'+#./;?&';

/**
 * Parsable templates have the following restrictions over expandable
 * templates:
 *
 *  * URI components must come in order: scheme, host, path, query, fragment,
 *    and there can only be one of each.
 *  * Path expressions can only contain one variable, and multiple expressions
 *    must be separated by a literal
 *  * Only the following operators are supported: default, +, #, ?, &
 *  * default and + operators are not allowed in query or fragment components
 *  * Queries can only use the ? or & operator. The ? operator can only be used
 *    once.
 *  * Fragments can only use the # operator
 *
 *  By default, fragments are treated as patchs and prefix-matched. This means
 *  that the template '#foo' will match against the fragments `#foo`, and
 *  `#foo/bar`, but not `#foobar`. This is to facilitate hierarchical matching
 *  in client-side routing applications, a likely use case, since fragments are
 *  not usually available to servers. You can turn off fragment prefix-matching
 *  with the `fragmentPrefixMatching` construtor parameter.
 */
class UriParser extends UriPattern {
  static final _pathSeparators = new RegExp('[./]');

  final UriTemplate template;
  final bool _fragmentPrefixMatching;
  final bool _queryParamsAreOptional;

  RegExp _pathRegex;
  List<String> _pathVariables;
  Map<String, String> _queryVariables;
  RegExp _fragmentRegex;
  List<String> _fragmentVariables;

  // TODO(justinfagnani): remove
  RegExp get fragmentRegex => _fragmentRegex;
  RegExp get pathRegex => _pathRegex;

  UriParser(UriTemplate this.template, {
    bool fragmentPrefixMatching: true,
    bool queryParamsAreOptional: false})
      : _fragmentPrefixMatching = firstNonNull(fragmentPrefixMatching, true),
        _queryParamsAreOptional = firstNonNull(queryParamsAreOptional, false) {
    if (template == null) throw new ArgumentError("null template A");
    var compiler = new _Compiler(template);
    _pathRegex = compiler.pathRegex;
    _pathVariables = compiler.pathVariables;
    _queryVariables = compiler.queryVariables;
    _fragmentRegex = compiler.fragmentRegex;
    _fragmentVariables = compiler.fragmentVariables;
  }

  String toString() => '$template';

  /**
   * Parses [uriString] returning the parameter values in a map keyed by the
   * variable names in the template.
   */
  Map<String, String> parse(Uri uri) {
    var parameters = {};

    if (_pathVariables.isNotEmpty) {
      var match = _pathRegex.firstMatch(uri.path);

      if (match == null) {
        throw new ParseException('$template does not match $uri');
      }
      int i = 1;
      for (var param in _pathVariables) {
        parameters[param] = match.group(i++);
      }
    }

    if (_queryVariables.isNotEmpty) {
      for (var key in _queryVariables.keys) {
        if (_queryVariables[key] == null) {
          parameters[key] = uri.queryParameters[key];
        }
      }
    }

    if (_fragmentRegex != null) {
      var match = _fragmentRegex.firstMatch(uri.fragment);
      if (match == null) {
        throw new ParseException('$template does not match $uri');
      }
      int i = 1;
      for (var param in _fragmentVariables) {
        parameters[param] = match.group(i++);
      }
    }
    return parameters;
  }

  UriMatch match(Uri uri) {
    var parameters = {};
    var restUriBuilder = new UriBuilder();

    if (_pathRegex != null) {
      var match = _pathRegex.matchAsPrefix(uri.path);
      if (match == null) {
        return null;
      } else {
        int i = 1;
        for (var param in _pathVariables) {
          parameters[param] = match.group(i++);
        }
        if (match.end < uri.path.length) {
          if (_pathSeparators.hasMatch(uri.path[match.end])) {
            restUriBuilder.path = uri.path.substring(match.end + 1);
          } else if (_pathSeparators.hasMatch(uri.path[match.end - 1])) {
            restUriBuilder.path = uri.path.substring(match.end);
          } else {
            return null;
          }
        }
      }
    } else {
      restUriBuilder.path = uri.path;
    }

    restUriBuilder.queryParameters.addAll(uri.queryParameters);

    if (_queryVariables.isNotEmpty) {
      // TODO(justinfagnani): remove matched parameters?
      for (var key in _queryVariables.keys) {
        var value = _queryVariables[key];
        if (value == null) {
          if (_queryParamsAreOptional || uri.queryParameters.containsKey(key)) {
            parameters[key] = uri.queryParameters[key];
          } else {
            return null;
          }
        } else if (uri.queryParameters[key] != value) {
          return null;
        }
      }
    }

    if (_fragmentRegex != null) {
      if (uri.fragment.isEmpty) return null;
      var match = _fragmentRegex.matchAsPrefix(uri.fragment);
      var prefixMatch = _fragmentPrefixMatching &&
          _pathSeparators.hasMatch(uri.fragment);
      if (match == null || (!prefixMatch && match.end != uri.fragment.length)) {
        return null;
      } else {
        int i = 1;
        for (var param in _fragmentVariables) {
          parameters[param] = match.group(i++);
        }
        if (prefixMatch) {
          if (match.end < uri.fragment.length) {
            if (_pathSeparators.hasMatch(uri.fragment[match.end])) {
              restUriBuilder.fragment = uri.fragment.substring(match.end + 1);
            } else if (_pathSeparators.hasMatch(uri.fragment[match.end - 1])) {
              restUriBuilder.fragment = uri.fragment.substring(match.end);
            } else {
              return null;
            }
          }
        }
      }
    }
    return new UriMatch(this, uri, parameters, restUriBuilder.build());
  }

  Uri expand(Map<String, Object> parameters) =>
      Uri.parse(template.expand(parameters));
}

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

  UriTemplate(String template)
      : template = template,
        _parts = _compile(template);

  String toString() => template;

  static UnmodifiableListView _compile(String template) {
    var parts = [];
    template.splitMapJoin(_exprRegex,
        onMatch: (match) { return parts.add(match); },
        onNonMatch: (String nonMatch) {
          if (_literalVerifier.hasMatch(nonMatch)) {
            throw new ParseException(nonMatch);
          }
          if (nonMatch.isNotEmpty) parts.add(nonMatch);
        });
    return new UnmodifiableListView(parts);
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
            str = '$value';
            if (prefixLength > 0 && prefixLength < str.length) {
              str = str.substring(0, prefixLength);
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

  bool operator ==(o) => o is UriTemplate && o.template == template;

  int get hashCode => template.hashCode;
}

/*
 * Compiles a template into a set of regexes and variable names to be used for
 * parsing URIs.
 *
 * How the compiler works:
 *
 * Processing starts off in 'path' mode, then optionaly switches to 'query'
 * mode, and then to 'fragment' mode if those sections are encountered in the
 * template.
 *
 * The template is first split into literal and expression parts. Then each part
 * is processed. If the part is a literal, it's checked for URI query and
 * fragment parts, and if it contains one processing is handed off to the
 * appropriate _compileX method. If the part is a Match, then it's an expression
 * and the operator is checked, if it's a '?' or '#' processing is also handed
 * over to the next _compileX method.
 */
class _Compiler {
  final Iterator _parts;

  RegExp pathRegex;
  final List<String> pathVariables = [];

  final Map<String, String> queryVariables = {};

  RegExp fragmentRegex;
  final List<String> fragmentVariables = [];

  _Compiler(UriTemplate template) : _parts = template._parts.iterator {
    _compilePath();
  }

  _compilePath() {
    StringBuffer pathBuffer = new StringBuffer();

    while (_parts.moveNext()) {
      var part = _parts.current;
      if (part is String) {
        var subparts = _splitLiteral(part);
        for (int i = 0; i < subparts.length; i++) {
          var subpart = subparts[i];
          if (subpart is String) {
            pathBuffer.write('(?:${escapeRegex(subpart)})');
          } else if ((subpart as Match).group(1) == '?') {
            _compileQuery(prevParts: subparts.sublist(i + 1));
            break;
          } else if ((subpart as Match).group(1) == '#') {
            _compileFragment(prevParts: subparts.sublist(i + 1));
            break;
          }
        }
      } else {
        Match match = part;
        var expr = match.group(3);
        var op = match.group(2);
        if (op == '') {
          pathBuffer.write(expr.split(',').map((varspec) {
            // store the variable name
            pathVariables.add(_varspecRegex.firstMatch(varspec).group(1));
            return r'((?:\w|[%-._~])+)';
          }).join(','));
        } else if (op == '+') {
          pathBuffer.write(expr.split(',').map((varspec) {
            // store the variable name
            pathVariables.add(_varspecRegex.firstMatch(varspec).group(1));
            // The + operator allows reserved chars, except ?, #, [,  and ]
            // which cannot appear in URI paths
            return r"((?:\w|[-._~:/@!$&'()*+,;=])+)";
          }).join(','));
        } else if (op == '?' || op == '&') {
          _compileQuery(match: match);
        } else if (op == '#') {
          _compileFragment(match: match);
        }
      }
    }
    if (pathBuffer.isNotEmpty) {
      pathRegex = new RegExp(pathBuffer.toString());
    }
  }

  void _compileQuery({Match match, List prevParts}) {
    handleExpressionMatch(Match match) {
      var expr = match.group(3);
      for (var q in expr.split(',')) {
        // TODO: handle modifiers
        var key = _varspecRegex.firstMatch(q).group(1);
        queryVariables[key] = null;
      }
    }

    handleLiteralParts(List literalParts) {
      for (int i = 0; i < literalParts.length; i++) {
        var subpart = literalParts[i];
        if (subpart is String) {
          queryVariables.addAll(_parseMap(subpart, '&'));
        }
        else if ((subpart as Match).group(1) == '?') {
          throw new ParseException('multiple queries');
        } else if ((subpart as Match).group(1) == '#') {
          return _compileFragment(prevParts: literalParts.sublist(i + 1));
        }
      }
    }

    if (match != null) {
      handleExpressionMatch(match);
    }
    if (prevParts != null) {
      handleLiteralParts(prevParts);
    }
    while (_parts.moveNext()) {
      var part = _parts.current;
      if (part is String) {
        handleLiteralParts(_splitLiteral(part));
      } else {
        Match match = part;
        var op = match.group(2);
        if (op == '&') {
          // add a query variable
          handleExpressionMatch(match);
        } else if (op == '?') {
          throw new ParseException('multiple queries');
        } else if (op == '#') {
          _compileFragment(match: match);
          return;
        } else {
          // TODO: add a query variable if the expr is in a value position?
          throw new ParseException('invalid operator for query part');
        }
      }
    }
  }

  void _compileFragment({Match match, List prevParts}) {
    var fragmentBuffer = new StringBuffer();

    handleExpressionMatch(Match match) {
      var expr = match.group(3);
      fragmentBuffer.write(expr.split(',').map((varspec) {
        // store the variable name
        fragmentVariables.add(_varspecRegex.firstMatch(varspec).group(1));
        return r'((?:\w|%)*)';
      }).join(','));
    }

    if (match != null) {
      handleExpressionMatch(match);
    }

    if (prevParts != null) {
      for (int i = 0; i < prevParts.length; i++) {
        var subpart = prevParts[i];
        if (subpart is String) {
          fragmentBuffer.write('(?:${escapeRegex(subpart)})');
        } else if ((subpart as Match).group(1) == '?') {
          throw new ParseException('?');
        } else if ((subpart as Match).group(1) == '#') {
          throw new ParseException('#');
        }
      }
    }
    while (_parts.moveNext()) {
      var part = _parts.current;
      if (part is String) {
        fragmentBuffer.write('(?:${escapeRegex(part)})');
      } else {
        Match match = part;
        var op = match.group(2);
        if (op == '#') {
          handleExpressionMatch(match);
        } else {
          // TODO: add a query variable if the expr is in a value position?
          throw new ParseException('invalid operator for fragment part');
        }
      }
    }
    if (fragmentBuffer.isNotEmpty) {
      fragmentRegex = new RegExp(fragmentBuffer.toString());
    }
  }

}

Map<String, String> _parseMap(String s, String separator) {
  var map = {};
  var kvPairs = s.split(separator);
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
  return map;
}

List _splitLiteral(String literal) {
  var subparts = [];
  literal.splitMapJoin(_fragmentOrQueryRegex,
      onMatch: (m) => subparts.add(m),
      onNonMatch: (s) => subparts.add(s));
  return subparts;
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
