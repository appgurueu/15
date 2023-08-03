library;

import "dart:math";

typedef Board = int;
typedef Tile = int;

const Board winningBoard = 0x0FEDCBA987654321;

Tile getTile(Board board, int i) {
  return (board >> (i << 2)) & 0xF;
}

Board setTile(Board board, int i, Tile tile) {
  final bitIdx = i << 2;
  return (board & ~(0xF << bitIdx)) | (tile << bitIdx);
}

Board swapTiles(Board board, int i, int j) {
  int a = getTile(board, i);
  int b = getTile(board, j);
  return setTile(setTile(board, i, b), j, a);
}

Board moveHoleTo(Board board, int newHolePos) {
  int bitPos = (flip(board) & 0xF) << 2;
  int newBitPos = newHolePos << 2;
  int val = (board >> newBitPos) & 0xF;
  return board ^ (val << bitPos) ^ (val << newBitPos);
}

/// Invert ("flip") the permutation of 0 - 15.
Board flip(Board board) {
  Board res = 0;
  for (int i = 0; i < 0x10; i++) {
    final tile = board & 0xF;
    res |= i << (tile << 2);
    board >>= 4;
  }
  return res;
}

bool isSolvable(Board board) {
  int inversions = 0;
  for (int i = 0; i < 0x10; i++) {
    for (int j = i + 1; j < 0x10; j++) {
      final a = getTile(board, i);
      final b = getTile(board, j);
      if (a != 0 && b != 0 && a > b) inversions++;
    }
  }
  final (_, hy) = idxToPos(getTile(flip(board), 0));
  return (inversions + hy).isOdd;
}

String toHex(Board board, [String rowsep = ""]) {
  return Iterable.generate(
      4,
      (y) => Iterable.generate(
              4, (x) => getTile(board, posToIdx(x, y)).toRadixString(0x10))
          .join()).join(rowsep);
}

Board _pack(Iterable<int> nums) {
  assert(nums.length == 0x10);
  return nums.fold(0, (board, tile) => (board << 4) | tile);
}

Board? fromHex(String hex) {
  if (!RegExp(r"^[\da-fA-F]{16}$").hasMatch(hex)) return null;
  return _pack(hex.codeUnits
      .map((c) => int.parse(String.fromCharCode(c), radix: 16))
      .toList()
      .reversed);
}

Board shuffle(Board board, int minMoves, int maxMoves) {
  var holePos = flip(board) & 0xF;
  final rand = Random();
  final moves = rand.nextInt(maxMoves) + minMoves;
  for (int i = 0; i <= moves; i++) {
    List<int> options = [];
    if (holePos > 3) options.add(-4);
    if (holePos < 12) options.add(4);
    int x = holePos & 3;
    if (x > 0) options.add(-1);
    if (x < 3) options.add(1);
    int delta = options[rand.nextInt(options.length)];
    int bitPos = holePos << 2;
    holePos += delta;
    int newBitPos = holePos << 2;
    int val = (board >> newBitPos) & 0xF;
    board ^= (val << bitPos) ^ (val << newBitPos);
  }
  return board;
}

Board randomSolvable() {
  return shuffle(winningBoard, 100, 1000);
}

int posToIdx(int x, int y) {
  return (y << 2) + x;
}

(int, int) idxToPos(int idx) {
  return (idx & 3, idx >> 2);
}

Iterable<Board> solveBFS(int solved, int toSolve, Board start) {
  int flippedMask = (toSolve << 4) | 0xF; // holes matter!
  bool predicate(Board board) => board & toSolve == winningBoard & toSolve;
  if (predicate(start)) return const Iterable.empty();
  List<(Board, Board)> level = [(start, flip(start))];
  Map<Board, Board> predecessor = {flip(start) & flippedMask: 0};
  while (level.isNotEmpty) {
    List<(Board, Board)> nextLevel = [];
    for (final tup in level) {
      final (board, flipped) = tup;
      final holePos = flipped & 0xF;
      Iterable<Board>? move(int dx, int dy) {
        int bitPos = holePos << 2;
        int newHolePos = holePos + posToIdx(dx, dy);
        int newBitPos = newHolePos << 2;
        if ((0xF << newBitPos) & solved != 0) return null;
        int val = (board >> newBitPos) & 0xF;
        final newBoard = board ^ (val << bitPos) ^ (val << newBitPos);
        int valPos = val << 2;
        final newFlipped =
            (((flipped & ~0xF) | newHolePos) & ~(0xF << valPos)) |
                (holePos << valPos);
        if (!predecessor.containsKey(newFlipped & flippedMask)) {
          predecessor[newFlipped & flippedMask] = board;
          if (predicate(newBoard)) {
            List<Board> solution = [newBoard];
            Board preBoard = board;
            while (preBoard != start) {
              solution.add(preBoard);
              preBoard = predecessor[flip(preBoard) & flippedMask]!;
            }
            return solution.reversed;
          }
          nextLevel.add((newBoard, newFlipped));
        }
        return null;
      }

      // Hot loop + no macros = ugly boilerplate (or error abuse or the like)
      final (hx, hy) = idxToPos(holePos);
      if (hx > 0) {
        final res = move(-1, 0);
        if (res != null) return res;
      }
      if (hx < 3) {
        final res = move(1, 0);
        if (res != null) return res;
      }
      if (hy > 0) {
        final res = move(0, -1);
        if (res != null) return res;
      }
      if (hy < 3) {
        final res = move(0, 1);
        if (res != null) return res;
      }
    }
    level = nextLevel;
  }
  throw "unsolvable";
}

Iterable<Board> solve(Board start) {
  const row1 = 0xFFFF;
  const row2 = row1 << 16;
  const upperHalf = row2 | row1;

  final row1Sol = solveBFS(0, row1, start);
  final row2Sol = solveBFS(row1, upperHalf, row1Sol.lastOrNull ?? start);
  final lowerSolution = solveBFS(
      upperHalf, ~0, row2Sol.lastOrNull ?? row1Sol.lastOrNull ?? start);

  return row1Sol.followedBy(row2Sol).followedBy(lowerSolution);
}
