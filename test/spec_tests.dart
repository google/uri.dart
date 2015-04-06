// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri.spec_tests;

import 'dart:io';
import 'dart:convert' show JSON;
import 'package:test/test.dart';
import 'package:uri/uri.dart';

void runSpecTests(String testname, {solo}) {
  var testFile = new File('test/uritemplate-test/$testname.json');
  var testJson = JSON.decode(testFile.readAsStringSync());

  for (var specGroup in testJson.keys) {
    group(specGroup, () {
      var data = testJson[specGroup];
      var variables = data['variables'];
      var testCases = data['testcases'];

      for (List testCase in testCases) {
        String templateString = testCase[0];
        if (solo != null && templateString == solo) continue;
        test(templateString, () {
          var expectation = testCase[1];
          if (expectation == false) {
            expect(() {
              var template = new UriTemplate(templateString);
              var r = template.expand(variables);
            }, throws, reason: templateString);
          } else {
            var template = new UriTemplate(templateString);
            var r = template.expand(variables);
            if (expectation is List) {
              expect(r, isIn(expectation), reason: templateString);
            } else {
              expect(r, expectation,
                  reason: "template: $templateString variables: $variables");
            }
          }
        });
      }
    });
  }
}

void main() {
  if (!new File('test/uritemplate-test/spec-examples.json').existsSync()) {
    print("spec examples not found. Make sure you run tests from the project"
        " directory, or try running `git submodule update`.");
    exit(1);
  }

  runSpecTests('spec-examples');
  runSpecTests('spec-examples-by-section');
  runSpecTests('extended-tests');
  runSpecTests('negative-tests');
}
