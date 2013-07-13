// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri_template_test;

import 'package:unittest/unittest.dart';
import 'package:uri_template/uri_template.dart';

main() {
 group('UriTemplate.parse', () {

   test('should parse simple variables', () {
     expectParse('/head/{a}/{b}/tail', '/head/x/y/tail', {'a': 'x', 'b': 'y'},
         reverse: true);
   });

   test('should parse multiple variables per expression', () {
     expectParse('{a,b}', 'xx,yy', {'a': 'xx', 'b': 'yy'},
         reverse: true);
   });

   test('should ignore explode and prefix modifiers', () {
     // TODO(justin): should a prefix modifier affect matching?
     expectParse('/head/{a*}/{b:3}', '/head/x/y', {'a': 'x', 'b': 'y'},
         reverse: true);
   });

   test('should parse reserved variables', () {
     expectParse('/head/{+a}/tail', '/head/xx/yy/tail', {'a': 'xx/yy'},
         reverse: true);
     // ?, #, [,  and ] cannot appear in URI paths, so don't include them in
     // the reserved char set
     var reservedChars = r":/@!$&'()*+,;=";
     for (var c in reservedChars.split('')) {
       expectParse('{+a}', c, {'a': c}, reverse: true);
     }
   });

   test('should parse query variables', () {
     expectParse('/foo{?a,b}', '/foo?a=xx&b=yy', {'a': 'xx', 'b': 'yy'});
     expectParse('/foo{?a,b}', '/foo?b=yy&a=xx', {'a': 'xx', 'b': 'yy'});
     expectParse('/foo{?a,b}', '/foo?b=yy&a=xx&c=zz', {'a': 'xx', 'b': 'yy'});
   });

   test('should parse path and query variables', () {
     expectParse('/{path}{?a,b}', '/foo?a=xx&b=yy',
         {'path': 'foo', 'a': 'xx', 'b': 'yy'});
   });

   test('should throw if path and query out of order', () {
     expect(() => new UriTemplate('/{?a,b}{path}').parse('x,y'), throws);
   });

   test('should parse fragment variables', () {
     expectParse('/foo{#a}', '/foo#xx', {'a': 'xx'});
     expectParse('/foo{#a,b}', '/foo#xx,yy', {'a': 'xx', 'b': 'yy'});
     expectParse('/foo{#a,b}', '/foo#xx,', {'a': 'xx', 'b': ''});
   });

   test('should parse fragment key/value maps', () {
     expectParse('/foo{#map}', '/foo#a=x,b=y', {'map': {'a': 'x', 'b': 'y'}});
     expectParse('/foo{#map}', '/foo#a=,,b=', {'map': {'a': ',', 'b': ''}});
     // this is a weird case, we could go with b='' or b=','
     expectParse('/foo{#map}', '/foo#a=,b=,', {'map': {'a': '', 'b': ','}});
     expectParse('/foo{#map}', '/foo#a=b=x', {'map': {'a': 'b=x'}});
   });

 });
}

expectParse(template, uri, variables, {reverse: false}) {
  var uriTemplate = new UriTemplate(template);
  expect(uriTemplate.parse(uri), equals(variables));
  if (reverse) {
    expect(uriTemplate.expand(variables), uri);
  }
}
