import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_translator.dart';

import '../../../core/security/pattern_path.dart';

enum PatternPadStatus { idle, error, success }

class PatternLockPadController extends ChangeNotifier {
  int _revision = 0;
  int get revision => _revision;

  void clear() {
    _revision++;
    notifyListeners();
  }
}

class PatternLockPad extends StatefulWidget {
  const PatternLockPad({
    super.key,
    required this.onCompleted,
    this.controller,
    this.status = PatternPadStatus.idle,
    this.enabled = true,
    this.size = 292,
  });

  final ValueChanged<List<int>> onCompleted;
  final PatternLockPadController? controller;
  final PatternPadStatus status;
  final bool enabled;
  final double size;

  @override
  State<PatternLockPad> createState() => _PatternLockPadState();
}

class _PatternLockPadState extends State<PatternLockPad> {
  List<int> _selected = const [];
  Offset? _pointer;
  int _lastRevision = 0;

  @override
  void initState() {
    super.initState();
    _lastRevision = widget.controller?.revision ?? 0;
    widget.controller?.addListener(_handleController);
  }

  @override
  void didUpdateWidget(covariant PatternLockPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleController);
      _lastRevision = widget.controller?.revision ?? 0;
      widget.controller?.addListener(_handleController);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleController);
    super.dispose();
  }

  void _handleController() {
    final revision = widget.controller?.revision ?? 0;
    if (revision == _lastRevision) return;
    _lastRevision = revision;
    if (!mounted) return;
    setState(() {
      _selected = const [];
      _pointer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = switch (widget.status) {
      PatternPadStatus.error => scheme.error,
      PatternPadStatus.success => scheme.primary,
      PatternPadStatus.idle => scheme.secondary,
    };

    return Semantics(
      label: AppTranslator.translate(context, 'لوحة رسم نمط من تسع نقاط'),
      hint: 'مرر إصبعك فوق أربع نقاط أو أكثر ثم ارفعه',
      child: SizedBox.square(
        dimension: widget.size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.enabled ? _start : null,
          onPanUpdate: widget.enabled ? _update : null,
          onPanEnd: widget.enabled ? _end : null,
          onPanCancel: widget.enabled ? _cancel : null,
          child: CustomPaint(
            painter: _PatternPainter(
              selected: _selected,
              pointer: _pointer,
              lineColor: lineColor,
              idleColor: scheme.outlineVariant,
              surfaceColor: scheme.surface,
            ),
          ),
        ),
      ),
    );
  }

  void _start(DragStartDetails details) {
    setState(() {
      _selected = const [];
      _pointer = details.localPosition;
    });
    _appendHit(details.localPosition);
  }

  void _update(DragUpdateDetails details) {
    setState(() => _pointer = details.localPosition);
    _appendHit(details.localPosition);
  }

  void _appendHit(Offset position) {
    final node = _hitNode(position);
    if (node == null) return;
    final next = appendPatternNode(_selected, node);
    if (next.length == _selected.length) return;
    setState(() => _selected = next);
  }

  int? _hitNode(Offset position) {
    final cell = widget.size / 3;
    final threshold = cell * 0.32;
    for (var node = 0; node < 9; node++) {
      final center = _nodeCenter(node, widget.size);
      if ((position - center).distance <= threshold) return node;
    }
    return null;
  }

  void _end(DragEndDetails _) {
    final completed = List<int>.unmodifiable(_selected);
    setState(() => _pointer = null);
    if (completed.isNotEmpty) widget.onCompleted(completed);
  }

  void _cancel() {
    setState(() {
      _selected = const [];
      _pointer = null;
    });
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.selected,
    required this.pointer,
    required this.lineColor,
    required this.idleColor,
    required this.surfaceColor,
  });

  final List<int> selected;
  final Offset? pointer;
  final Color lineColor;
  final Color idleColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dimension = math.min(size.width, size.height);
    final centers = [
      for (var node = 0; node < 9; node++) _nodeCenter(node, dimension),
    ];
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (selected.length > 1) {
      final path = Path()
        ..moveTo(centers[selected.first].dx, centers[selected.first].dy);
      for (final node in selected.skip(1)) {
        path.lineTo(centers[node].dx, centers[node].dy);
      }
      canvas.drawPath(path, linePaint);
    }
    if (selected.isNotEmpty && pointer != null) {
      canvas.drawLine(centers[selected.last], pointer!, linePaint);
    }

    final outerRadius = dimension / 22;
    final selectedRadius = dimension / 30;
    for (var node = 0; node < 9; node++) {
      final isSelected = selected.contains(node);
      final outerPaint = Paint()
        ..color = isSelected ? lineColor.withValues(alpha: 0.22) : surfaceColor
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = isSelected ? lineColor : idleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 2;
      canvas
        ..drawCircle(centers[node], outerRadius, outerPaint)
        ..drawCircle(centers[node], outerRadius, borderPaint);
      if (isSelected) {
        canvas.drawCircle(
          centers[node],
          selectedRadius,
          Paint()..color = lineColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.pointer != pointer ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.idleColor != idleColor ||
      oldDelegate.surfaceColor != surfaceColor;
}

Offset _nodeCenter(int node, double size) {
  final cell = size / 3;
  final row = node ~/ 3;
  final column = node % 3;
  return Offset((column * cell) + (cell / 2), (row * cell) + (cell / 2));
}
