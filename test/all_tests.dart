// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri.all_tests;

import 'dart:io';
import 'package:path/path.dart' as path;

import 'encoding_test.dart' as encoding;
import 'spec_tests.dart' as spec;
import 'uri_builder_test.dart' as builder;
import 'uri_parser_test.dart' as parser;
import 'uri_template_test.dart' as template;
import 'uri_test.dart' as uri;

void main() {
  // Attempt to set the working directory to the project directory so that
  // the spec tests, which access files, run correctly.
  var cwd = path.split(Directory.current.path);
  if (cwd.last == 'test') {
    Directory.current = path.joinAll(cwd.sublist(0, cwd.length - 1));
  }

  builder.main();
  encoding.main();
  parser.main();
  spec.main();
  template.main();
  uri.main();
}
