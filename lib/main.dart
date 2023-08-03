import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'board.dart' as brd;

typedef Board = brd.Board;
typedef Tile = brd.Tile;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '15',
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.light,
        colorSchemeSeed: Colors.lightBlueAccent,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class _TileWidget extends StatelessWidget {
  final Tile tile;
  final Function()? onPressed;
  final bool muted;
  const _TileWidget(this.tile, this.onPressed, {this.muted = false});
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(2),
        child: FilledButton(
          key: ValueKey<int>(tile),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: Color.fromARGB(255, 67, 170, 230),
              disabledBackgroundColor: muted
                  ? const Color.fromARGB(255, 190, 217, 233)
                  : const Color.fromARGB(255, 134, 198, 238)),
          child: Text(tile == 0 ? "" : tile.toString(),
              style: DefaultTextStyle.of(context)
                  .style
                  .apply(fontSizeFactor: 2.0)),
        ));
  }
}

class _GameWidget extends StatefulWidget {
  const _GameWidget();
  @override
  State<_GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<_GameWidget> {
  Board board;
  Future<List<Board>>? solving;
  Timer? solutionStepper;
  bool editing = false;
  _GameWidgetState() : board = brd.randomSolvable();

  bool get won => board == brd.winningBoard;

  _move(int toIdx) {
    setState(() {
      board = brd.moveHoleTo(board, toIdx);
    });
  }

  _slide(int dx, int dy) {
    if (solutionStepper != null || solving != null || editing) return;
    var (hx, hy) = brd.idxToPos(brd.getTile(brd.flip(board), 0));
    // It is more intuitive to slide in the opposite direction of hole movement.
    hx -= dx;
    hy -= dy;
    if (hx < 0 || hx > 3 || hy < 0 || hy > 3) return;
    _move(brd.posToIdx(hx, hy));
  }

  _solve() {
    setState(() {
      solving = compute((board) => brd.solve(board).toList(), board);
    });
  }

  _stop() {
    if (solutionStepper == null) return;
    setState(() {
      solutionStepper!.cancel();
      solutionStepper = null;
    });
  }

  _shuffle() {
    setState(() {
      board = brd.randomSolvable();
      solving = null;
      if (solutionStepper != null) {
        solutionStepper!.cancel();
        solutionStepper = null;
      }
    });
  }

  _edit() {
    _stop();
    setState(() {
      editing = true;
    });
  }

  _done() {
    setState(() {
      editing = false;
    });
  }

  _copy() {
    Clipboard.setData(ClipboardData(text: brd.toHex(board)));
  }

  _paste() {
    Clipboard.getData(Clipboard.kTextPlain).then((value) {
      final text = value?.text;
      if (text == null) return;
      setState(() {
        final clippedboard = brd.fromHex(text);
        if (clippedboard != null) board = clippedboard;
      });
    });
  }

  _reset() {
    setState(() {
      board = brd.winningBoard;
    });
  }

  Widget _build() {
    final (hx, hy) = brd.idxToPos(brd.flip(board) & 0xF);
    final buttons = Iterable.generate(
        4,
        (y) => Iterable.generate(4, (x) {
              final idx = brd.posToIdx(x, y);
              Tile tile = brd.getTile(board, idx);
              if (editing) {
                final Widget child = _TileWidget(tile, null);
                return DragTarget<int>(
                  builder: (context, candidateData, rejectedData) =>
                      LayoutBuilder(
                          builder: (context, constraints) => Draggable<int>(
                                data: idx,
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                feedback: SizedBox(
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    child: DefaultTextStyle.of(context).wrap(
                                        context, _TileWidget(tile, null))),
                                childWhenDragging:
                                    _TileWidget(tile, null, muted: true),
                                child: child,
                              )),
                  onAccept: (int j) {
                    setState(() {
                      board = brd.swapTiles(board, idx, j);
                    });
                  },
                );
              }
              final neighbor = (x - hx).abs() + (y - hy).abs() == 1;
              return _TileWidget(
                tile,
                neighbor && solutionStepper == null
                    ? () {
                        _move(idx);
                      }
                    : null,
              );
            }).toList()).toList();
    final grid = GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: buttons.expand((x) => x).toList(),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: editing
              ? [
                  TextButton(onPressed: _shuffle, child: const Text("Shuffle")),
                  TextButton(onPressed: _reset, child: const Text("Reset")),
                  TextButton(
                      // TODO (...?) disable if clipboard content is invalid
                      onPressed: _paste,
                      child: const Text("Paste")),
                  FilledButton(
                      onPressed: brd.isSolvable(board) ? _done : null,
                      child: const Text("Done")),
                ]
              : [
                  TextButton(onPressed: _shuffle, child: const Text("Shuffle")),
                  TextButton(onPressed: _edit, child: const Text("Edit")),
                  TextButton(
                      onPressed: brd.isSolvable(board) ? _copy : null,
                      child: const Text("Copy")),
                  solutionStepper == null
                      ? FilledButton(
                          onPressed: won ? null : _solve,
                          child: const Text("Solve"))
                      : FilledButton(
                          onPressed: won ? null : _stop,
                          child: const Text("Stop")),
                ],
        ),
        Expanded(
            child: Center(
                child: Focus(
          autofocus: true,
          onKeyEvent: (_, keyEvent) {
            if (keyEvent is! KeyUpEvent) return KeyEventResult.ignored;
            switch (keyEvent.logicalKey) {
              case LogicalKeyboardKey.keyW:
                _slide(0, -1);
              case LogicalKeyboardKey.keyA:
                _slide(-1, 0);
              case LogicalKeyboardKey.keyS:
                _slide(0, 1);
              case LogicalKeyboardKey.keyD:
                _slide(1, 0);
              default:
                return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: GestureDetector(
              onHorizontalDragEnd: (DragEndDetails details) {
                if (details.primaryVelocity == null) return;
                _slide(details.primaryVelocity!.sign.toInt(), 0);
              },
              onVerticalDragEnd: (DragEndDetails details) {
                if (details.primaryVelocity == null) return;
                _slide(0, details.primaryVelocity!.sign.toInt());
              },
              child: grid),
        ))),
        TextButton(
            onPressed: () {
              launchUrl(Uri.parse("https://en.wikipedia.org/wiki/15_puzzle"),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text("About")),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (solving != null) {
      return FutureBuilder<List<Board>>(
        future: solving,
        builder: (context, snapshot) {
          assert(!snapshot.hasError);
          if (snapshot.hasData) {
            solving = null;
            final data = snapshot.data!;
            int i = 0;
            solutionStepper = Timer.periodic(
                const Duration(seconds: 1),
                (Timer t) => setState(() {
                      if (i == data.length) {
                        solutionStepper!.cancel();
                        solutionStepper = null;
                        return;
                      }
                      board = data[i];
                      i++;
                    }));
            return _build();
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    }
    return _build();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _MyHomePageState();

  @override
  Widget build(BuildContext context) {
    const body = _GameWidget();
    if (true) {
      return Scaffold(
          body: Container(
        padding: EdgeInsets.fromLTRB(
            0, MediaQuery.of(context).viewPadding.top, 0, 0),
        child: body,
      ));
    }
    switch (Theme.of(context).platform) {
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return body; // no scaffolding if there likely already is a window bar
      default:
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text("15"),
          ),
          body: body,
        );
    }
  }
}
