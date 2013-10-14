// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri_template.utils;

class UriBuilder {
  String scheme;
  String host = '';
  int port = 0;
  String path = '';
  Map<String, String> queryParameters = {};
  String fragment = '';

  Uri build() => new Uri(scheme: scheme, host: host, port: port, path: path,
      queryParameters: queryParameters, fragment: fragment);
}
