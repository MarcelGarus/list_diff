import 'dart:math';

import 'package:flutter/material.dart';
import 'package:list_diff/list_diff.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.red),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int get numSamples => spawnTimes.length;

  String message;

  final spawnTimes = <double>[];
  double get spawnTimesAverage => spawnTimes.isEmpty
      ? null
      : spawnTimes.reduce((a, b) => a + b) / spawnTimes.length;

  final timesPerCell = <double>[];
  double get timesPerCellAverage => timesPerCell.isEmpty
      ? null
      : timesPerCell.reduce((a, b) => a + b) / timesPerCell.length;

  void _profileTick() async {
    var r = Random();
    var stopwatch = Stopwatch();
    var a = List.generate(r.nextInt(900) + 100, (_) => r.nextInt(100));
    var b = List.generate(r.nextInt(900) + 100, (_) => r.nextInt(100));

    stopwatch.start();
    await diff(a, b, spawnIsolate: false);
    var withoutIsolate = stopwatch.elapsedMicroseconds;
    stopwatch
      ..reset()
      ..start();
    await diff(a, b, spawnIsolate: true);
    var withIsolate = stopwatch.elapsedMicroseconds;
    var spawnTime = (withIsolate - withoutIsolate).clamp(0, 10000000000);
    var timePerCell = withoutIsolate / (a.length + 1) / (b.length + 1);
    setState(() {
      message =
          'Diffed ${a.length}x${b.length} lists. Without isolate: $withoutIsolate ys';
      spawnTimes.add(spawnTime.toDouble());
      timesPerCell.add(timePerCell);
    });
  }

  @override
  void initState() {
    super.initState();
    _profile();
  }

  void _profile() async {
    while (true) {
      await Future.delayed(Duration(milliseconds: 500));
      _profileTick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Samples: $numSamples'),
            Text('Spawn time: $spawnTimesAverage'),
            Text('Times per cell: $timesPerCellAverage'),
          ],
        ),
      ),
    );
  }
}
