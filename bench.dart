import 'dart:io';
import 'dart:math';

import 'lib/board.dart' as brd;

typedef Board = brd.Board;

// ignore_for_file: avoid_print

usage() {
  print("arg: <n trials>");
  exit(1);
}

void main(List<String> args) {
  if (args.length > 1) usage();
  int n = 100;
  if (args.length == 1) {
    final arg = int.tryParse(args[0]);
    if (arg == null) {
      usage();
    } else {
      n = arg;
    }
  }
  int mn = 0x7FFFFFFFFFFFFFFF, mx = 0, sum = 0;
  for (int i = 0; i < n; i++) {
    final b = brd.randomSolvable();
    final stopwatch = Stopwatch();
    stopwatch.start();
    brd.solve(b);
    stopwatch.stop();
    final ms = stopwatch.elapsedMilliseconds;
    mn = min(mn, ms);
    mx = max(mx, ms);
    sum += ms;
  }
  final avg = sum.toDouble() / n;
  print("min: $mn, avg: $avg, max: $mx [ms]");
}
