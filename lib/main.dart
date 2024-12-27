import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Color? disabledBackgroundColor;
  final bool showBlank;
  const _TileWidget(this.tile, this.onPressed,
      {this.disabledBackgroundColor = const Color.fromARGB(255, 134, 198, 238),
      this.showBlank = false});
  @override
  Widget build(BuildContext context) {
    if (tile == 0 && !showBlank) return Container();
    return Container(
        padding: const EdgeInsets.all(2),
        child: FilledButton(
          key: ValueKey<int>(tile),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 67, 170, 230),
              disabledBackgroundColor: disabledBackgroundColor),
          child: Text(tile == 0 ? "" : tile.toString(),
              style: DefaultTextStyle.of(context)
                  .style
                  .apply(fontSizeFactor: 2.0)),
        ));
  }
}

class _DraggableTileWidget extends StatelessWidget {
  final Tile tile;
  final int idx;
  final Function(Tile) onAccept;
  const _DraggableTileWidget(this.tile, this.idx, this.onAccept);
  @override
  Widget build(BuildContext context) {
    final Widget child = _TileWidget(tile, null, showBlank: true);
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) => LayoutBuilder(
          builder: (context, constraints) => Draggable<int>(
                data: idx,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: DefaultTextStyle.of(context).wrap(context, child)),
                childWhenDragging: _TileWidget(
                  tile,
                  null,
                  disabledBackgroundColor:
                      const Color.fromARGB(255, 190, 217, 233),
                  showBlank: true,
                ),
                child: child,
              )),
      onAcceptWithDetails: (dragTargetDetails) {
        onAccept(dragTargetDetails.data); 
      },
    );
  }
}

class _GameWidget extends StatefulWidget {
  final SharedPreferences? prefs;
  const _GameWidget(this.prefs);
  @override
  State<_GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<_GameWidget> {
  Board _board;
  Board get board => _board;
  bool get won => board == brd.winningBoard;
  set board(Board board) {
    _board = board;
    _persist();
  }

  bool _editing = false;
  bool get editing => _editing;
  set editing(bool editing) {
    _editing = editing;
    _persist();
  }

  // These two are deliberately not persisted
  Future<List<Board>>? _solving;
  Timer? _solutionStepper;

  _GameWidgetState() : _board = brd.randomSolvable();

  @override
  initState() {
    super.initState();
    if (widget.prefs == null) return;
    final SharedPreferences prefs = widget.prefs!;
    _editing = prefs.getBool('editing') ?? false;
    final boardHex = prefs.getString('board');
    if (boardHex != null) _board = brd.fromHex(boardHex) ?? _board;
    _persist();
  }

  _persist() {
    if (widget.prefs == null) return;
    final SharedPreferences prefs = widget.prefs!;
    prefs.setBool('editing', editing).then((success) {
      if (success) prefs.setString('board', brd.toHex(board));
      // TODO (...) log failure or notify user
    });
  }

  _move(int toIdx) {
    setState(() {
      board = brd.moveHoleTo(board, toIdx);
    });
  }

  _slide(int dx, int dy) {
    if (_solutionStepper != null || _solving != null || editing) return;
    var (hx, hy) = brd.idxToPos(brd.getTile(brd.flip(board), 0));
    // It is more intuitive to slide in the opposite direction of hole movement.
    hx -= dx;
    hy -= dy;
    if (hx < 0 || hx > 3 || hy < 0 || hy > 3) return;
    _move(brd.posToIdx(hx, hy));
  }

  _solve() {
    setState(() {
      _solving = compute((board) => brd.solve(board).toList(), board);
    });
  }

  _stop() {
    if (_solutionStepper == null) return;
    setState(() {
      _solutionStepper!.cancel();
      _solutionStepper = null;
    });
  }

  _shuffle() {
    setState(() {
      board = brd.randomSolvable();
      _solving = null;
      if (_solutionStepper != null) {
        _solutionStepper!.cancel();
        _solutionStepper = null;
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

  _swap(int i, j) {
    setState(() {
      board = brd.swapTiles(board, i, j);
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
                return _DraggableTileWidget(
                  tile,
                  idx,
                  (int j) => _swap(idx, j),
                );
              }
              final neighbor = (x - hx).abs() + (y - hy).abs() == 1;
              return _TileWidget(
                tile,
                neighbor && _solutionStepper == null
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
                  _solutionStepper == null
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
              // TODO make sure that this fires only for the primary axis
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
    if (_solving != null) {
      return FutureBuilder<List<Board>>(
        future: _solving,
        builder: (context, snapshot) {
          assert(!snapshot.hasError);
          if (snapshot.hasData) {
            _solving = null;
            final data = snapshot.data!;
            assert(data.isNotEmpty);
            int i = 0;
            _solutionStepper = Timer.periodic(
                const Duration(seconds: 1),
                (Timer t) => setState(() {
                      board = data[i];
                      i++;
                      if (i >= data.length) {
                        _solutionStepper!.cancel();
                        _solutionStepper = null;
                      }
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
    return Scaffold(
        body: Container(
      padding:
          EdgeInsets.fromLTRB(0, MediaQuery.of(context).viewPadding.top, 0, 0),
      child: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          // Behave gracefully if we don't have persistent storage.
          // TODO (...) log this or notify user about the issue
          if (snapshot.hasError) return const _GameWidget(null);
          if (snapshot.hasData) return _GameWidget(snapshot.data!);
          return const Center(child: CircularProgressIndicator());
        },
      ),
    ));
  }
}
