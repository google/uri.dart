// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'encoding_test.dart' as encoding;
import 'spec_tests.dart' as spec;
import 'uri_parser_test.dart' as parser;
import 'uri_template_test.dart' as template;

main() {
  encoding.main();
  spec.main();
  parser.main();
  template.main();
}
