import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Stage 4.8C Part 1 — the calculator [ExamModel.calculatorType] has
/// gated since Stage 4.8A but nothing actually offered. A standard
/// button-driven accumulator (not an expression parser), matching how
/// a physical exam calculator behaves: one pending operation at a
/// time, no operator precedence to reason about. [CalculatorType.basic]
/// gets +, -, ×, ÷, %, and sign-flip; [CalculatorType.scientific] adds
/// a second row of trig/log/power functions applied directly to the
/// value on screen.
Future<void> showExamCalculatorSheet(BuildContext context, CalculatorType type) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CalculatorSheet(type: type),
  );
}

class _CalculatorSheet extends StatefulWidget {
  final CalculatorType type;
  const _CalculatorSheet({required this.type});

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  String _display = '0';
  double? _stored;
  String? _pendingOp;
  bool _justEnteredOperator = false;

  double get _current => double.tryParse(_display) ?? 0;

  void _inputDigit(String d) {
    setState(() {
      if (_display == '0' || _display == 'Error' || _justEnteredOperator) {
        _display = d;
        _justEnteredOperator = false;
      } else {
        _display += d;
      }
    });
  }

  void _inputDecimal() {
    setState(() {
      if (_justEnteredOperator || _display == 'Error') {
        _display = '0.';
        _justEnteredOperator = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _setOperator(String op) {
    setState(() {
      if (_stored != null && !_justEnteredOperator) {
        _stored = _applyPending(_stored!, _current);
        _display = _formatResult(_stored!);
      } else {
        _stored = _current;
      }
      _pendingOp = op;
      _justEnteredOperator = true;
    });
  }

  double _applyPending(double a, double b) {
    switch (_pendingOp) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '\u00d7':
        return a * b;
      case '\u00f7':
        return b == 0 ? double.nan : a / b;
      default:
        return b;
    }
  }

  void _equals() {
    setState(() {
      if (_stored == null || _pendingOp == null) return;
      final result = _applyPending(_stored!, _current);
      _display = _formatResult(result);
      _stored = null;
      _pendingOp = null;
      _justEnteredOperator = false;
    });
  }

  void _clearAll() {
    setState(() {
      _display = '0';
      _stored = null;
      _pendingOp = null;
      _justEnteredOperator = false;
    });
  }

  void _backspace() {
    setState(() {
      if (_display == 'Error' || _display.length <= 1 || (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  void _negate() {
    setState(() {
      if (_display == '0') return;
      _display = _display.startsWith('-') ? _display.substring(1) : '-$_display';
    });
  }

  void _percent() {
    setState(() => _display = _formatResult(_current / 100));
  }

  void _applyUnary(double Function(double) fn) {
    setState(() {
      final result = fn(_current);
      _display = result.isNaN || result.isInfinite ? 'Error' : _formatResult(result);
      _justEnteredOperator = true;
    });
  }

  String _formatResult(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    final s = value.toStringAsFixed(8);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final isScientific = widget.type == CalculatorType.scientific;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isScientific ? 'Scientific calculator' : 'Calculator',
                  style: AppTextStyles.titleMedium(AppColors.textPrimary),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            Container(
              width: double.infinity,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Text(
                _display,
                style: AppTextStyles.displayLarge(AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isScientific) ...[
              _buttonRow([
                _CalcBtn('sin', () => _applyUnary((v) => math.sin(v * math.pi / 180))),
                _CalcBtn('cos', () => _applyUnary((v) => math.cos(v * math.pi / 180))),
                _CalcBtn('tan', () => _applyUnary((v) => math.tan(v * math.pi / 180))),
                _CalcBtn('\u221a', () => _applyUnary(math.sqrt)),
              ]),
              _buttonRow([
                _CalcBtn('log', () => _applyUnary((v) => math.log(v) / math.ln10)),
                _CalcBtn('ln', () => _applyUnary(math.log)),
                _CalcBtn('x\u00b2', () => _applyUnary((v) => v * v)),
                _CalcBtn('\u03c0', () => setState(() {
                      _display = _formatResult(math.pi);
                      _justEnteredOperator = true;
                    })),
              ]),
            ],
            _buttonRow([
              _CalcBtn('C', _clearAll, isFunction: true),
              _CalcBtn('\u2190', _backspace, isFunction: true),
              _CalcBtn('%', _percent, isFunction: true),
              _CalcBtn('\u00f7', () => _setOperator('\u00f7'), isOperator: true),
            ]),
            _buttonRow([
              _CalcBtn('7', () => _inputDigit('7')),
              _CalcBtn('8', () => _inputDigit('8')),
              _CalcBtn('9', () => _inputDigit('9')),
              _CalcBtn('\u00d7', () => _setOperator('\u00d7'), isOperator: true),
            ]),
            _buttonRow([
              _CalcBtn('4', () => _inputDigit('4')),
              _CalcBtn('5', () => _inputDigit('5')),
              _CalcBtn('6', () => _inputDigit('6')),
              _CalcBtn('-', () => _setOperator('-'), isOperator: true),
            ]),
            _buttonRow([
              _CalcBtn('1', () => _inputDigit('1')),
              _CalcBtn('2', () => _inputDigit('2')),
              _CalcBtn('3', () => _inputDigit('3')),
              _CalcBtn('+', () => _setOperator('+'), isOperator: true),
            ]),
            _buttonRow([
              _CalcBtn('\u00b1', _negate),
              _CalcBtn('0', () => _inputDigit('0')),
              _CalcBtn('.', _inputDecimal),
              _CalcBtn('=', _equals, isOperator: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buttonRow(List<_CalcBtn> buttons) {
    return Row(
      children: buttons
          .map((b) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _CalcButtonWidget(btn: b),
                ),
              ))
          .toList(),
    );
  }
}

class _CalcBtn {
  final String label;
  final VoidCallback onTap;
  final bool isOperator;
  final bool isFunction;
  _CalcBtn(this.label, this.onTap, {this.isOperator = false, this.isFunction = false});
}

class _CalcButtonWidget extends StatelessWidget {
  final _CalcBtn btn;
  const _CalcButtonWidget({required this.btn});

  @override
  Widget build(BuildContext context) {
    final bg = btn.isOperator
        ? AppColors.primaryBlue
        : btn.isFunction
            ? AppColors.textSecondary.withOpacity(0.15)
            : AppColors.backgroundLight;
    final fg = btn.isOperator ? Colors.white : AppColors.textPrimary;
    return AspectRatio(
      aspectRatio: 1.3,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: btn.onTap,
          child: Center(
            child: Text(btn.label, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
