import 'dart:io';

import 'lib/board.dart' as brd;

typedef Board = brd.Board;

// ignore_for_file: avoid_print

usage() {
  print("arg: <hex board>");
  exit(1);
}

void main(List<String> args) {
  if (args.length != 1) usage();
  Board? board = brd.fromHex(args[0]);
  if (board == null) usage();
  if (!brd.isSolvable(board!)) {
    print("unsolvable");
    exit(1);
  }
  final linefeed = Platform.isWindows ? "\r\n" : "\n";
  print([board]
      .followedBy(brd.solve(board))
      .map((b) => brd.toHex(b, linefeed))
      .join(linefeed + linefeed));
}
