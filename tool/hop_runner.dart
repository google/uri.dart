library hop_runner;

import 'package:unittest/unittest.dart';
import 'package:hop/hop.dart';
import 'package:hop/hop_tasks.dart';

//tests
import '../test/all_tests.dart' as tests;

void main(List<String> args) {
  List<String> paths = ["lib/uri.dart"];
  
  addTask('docs', createDartDocTask(paths));
  addTask('analyze', createAnalyzerTask(paths));
  addTask('test', createUnitTestTask((Configuration config){
    unittestConfiguration = config;
    tests.main();
  }));
  runHop(args);
}

