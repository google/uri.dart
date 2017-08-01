// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library uri.matchers;

import 'package:matcher/matcher.dart' show CustomMatcher, Description, Matcher,
    anything;

/**
 * Matches the individual parts of a [Uri]. If a matcher is not specified for a
 * part, the default matcher is [anything]. This allows you to just match on a
 * single part, like the scheme, while ignoring the rest.
 */
Matcher matchesUri({
  fragment: anything,
  host: anything,
  path: anything,
  port: anything,
  queryParameters: anything,
  scheme: anything,
  userInfo: anything
}) => new _CompoundMatcher([
    _feature('Uri', 'fragment', fragment, (i) => i.fragment),
    _feature('Uri', 'host', host, (i) => i.host),
    _feature('Uri', 'path', path, (i) => i.path),
    _feature('Uri', 'port', port, (i) => i.port),
    _feature('Uri', 'queryParameters', queryParameters, (i) => i.queryParameters),
    _feature('Uri', 'scheme', scheme, (i) => i.scheme),
    _feature('Uri', 'userInfo', userInfo, (i) => userInfo)]);

/**
 * Matches the parts of a [Uri] against [expected], all of which must equal for
 * the match to pass.
 */
Matcher equalsUri(Uri expected) => matchesUri(
    fragment: expected.fragment,
    host: expected.host,
    path: expected.path,
    port: expected.port,
    queryParameters: expected.queryParameters,
    scheme: expected.scheme,
    userInfo: expected.userInfo);

// TODO(justinfagnani): move the following to a common location

/**
 * Convenience function for creating [_FeatureMatcher]s.
 */
_FeatureMatcher _feature(String description, String name, matcher, extract(o)) =>
    new _FeatureMatcher(description, name, matcher, extract);

/**
 * A [CustomMatcher] that takes a function to extract a feature of the item
 * being matched, rather than requiring inheritance. This class implements
 * the [CustomMatcher.featureValueOf] method by calling [extract].
 */
class _FeatureMatcher extends CustomMatcher {
  final extract;

  _FeatureMatcher(String itemName, String featureName, matcher, this.extract)
      : super('$itemName with $featureName', featureName, matcher);

  featureValueOf(actual) => extract(actual);
}

// TODO(justinfagnani): maybe fix and change the behavior of allOf() in
// unittest instead of introducting this class

/**
 * A helper class for creating a single matcher out of several other matchers.
 *
 * When checking expectations of a complex object in a test, it's useful to be
 * able to specify matchers against several different features of the object at
 * once. With `CompoundMatcher` and [FeatureMatcher] this task is relatively
 * simple and makes tests easier to read.
 *
 * ## Example:
 *
 * Imagine we have a class called `Result` with fields `target`, `name` and
 * `value`. We can write a function that returns a custom matcher for
 * `Result`s like so:
 *
 *     Matcher matchesResult({
 *       target: anything,
 *       name: anything,
 *       value: anything}) => new CompoundMatcher<Result>([
 *           feature('Result', 'target', target, (e) => e.target),
 *           feature('Result', 'name', name, (e) => e.name),
 *           feature('Result', 'value', value, (e) => e.value)]);
 *
 * The default matchers are specified as [anything] so that if unspecified, any
 * value for the feature will match. You can use the matcher in tests like this:
 *
 *     group('getResult()', () {
 *       test('should have a value if given', () {
 *         // here we use a value as a matcher, which works like in expect()
 *         expect(getResult(123), matchesResult(value: 123));
 *       });
 *       test('should have a name starting with x', () {
 *         // here we use a more complex matcher
 *         expect(getResult(), matchesResult(name: startsWith('x')));
 *       });
 *       test('should have a target and value', () {
 *         // here we match on multiple features
 *         expect(getResult(123), matchesResult(target: isNotNull,
 *             value: greaterThan(100)));
 *       });
 *     });
 *
 * All feature matchers are run, even if there are mismatches. Any mismatches
 * are described properly in [describeMismatch].
 */
class _CompoundMatcher<T> extends Matcher {
  final List<Matcher> _matchers;

  _CompoundMatcher(this._matchers);

  bool matches(T item, Map matchState) {
    var states = new List.generate(_matchers.length, (i) => {});
    var statuses = new List.filled(_matchers.length, true);
    matchState['states'] = states;
    matchState['statuses'] = statuses;
    var result = true;

    for (var i = 0; i < _matchers.length; i++) {
      statuses[i] = _matchers[i].matches(item, states[i]);
      result = result && statuses[i];
    }
    return result;
  }

  Description describeMismatch(T item, Description mismatchDescription,
      Map matchState, bool verbose) {
    var statuses = matchState['statuses'];
    var states = matchState['states'];

    for (var i = 0; i < _matchers.length; i++) {
      if (!statuses[i]) {
        _matchers[i].describeMismatch(item, mismatchDescription, states[i],
            verbose);
      }
    }
    return mismatchDescription;
  }

  Description describe(Description description) {
    _matchers.forEach((m) => m.describe(description));
    return description;
  }
}
