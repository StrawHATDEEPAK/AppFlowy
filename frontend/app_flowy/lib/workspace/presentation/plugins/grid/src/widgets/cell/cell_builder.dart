import 'package:app_flowy/workspace/application/grid/cell/cell_service/cell_service.dart';
import 'package:flowy_sdk/protobuf/flowy-grid-data-model/grid.pb.dart' show FieldType;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:app_flowy/workspace/presentation/plugins/grid/src/widgets/row/grid_row.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_flowy/workspace/presentation/plugins/grid/src/layout/sizes.dart';
import 'package:styled_widget/styled_widget.dart';
import 'cell_accessory.dart';
import 'cell_shortcuts.dart';
import 'checkbox_cell.dart';
import 'date_cell/date_cell.dart';
import 'number_cell.dart';
import 'select_option_cell/select_option_cell.dart';
import 'text_cell.dart';
import 'url_cell/url_cell.dart';

GridCellWidget buildGridCellWidget(GridCell gridCell, GridCellCache cellCache, {GridCellStyle? style}) {
  final key = ValueKey(gridCell.cellId());

  final cellContextBuilder = GridCellContextBuilder(gridCell: gridCell, cellCache: cellCache);

  switch (gridCell.field.fieldType) {
    case FieldType.Checkbox:
      return CheckboxCell(cellContextBuilder: cellContextBuilder, key: key);
    case FieldType.DateTime:
      return DateCell(cellContextBuilder: cellContextBuilder, key: key, style: style);
    case FieldType.SingleSelect:
      return SingleSelectCell(cellContextBuilder: cellContextBuilder, style: style, key: key);
    case FieldType.MultiSelect:
      return MultiSelectCell(cellContextBuilder: cellContextBuilder, style: style, key: key);
    case FieldType.Number:
      return NumberCell(cellContextBuilder: cellContextBuilder, key: key);
    case FieldType.RichText:
      return GridTextCell(cellContextBuilder: cellContextBuilder, style: style, key: key);
    case FieldType.URL:
      return GridURLCell(cellContextBuilder: cellContextBuilder, style: style, key: key);
  }
  throw UnimplementedError;
}

class BlankCell extends StatelessWidget {
  const BlankCell({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

abstract class GridCellWidget extends StatefulWidget implements CellAccessory, CellFocustable, CellShortcuts {
  GridCellWidget({Key? key}) : super(key: key);

  @override
  final ValueNotifier<bool> isFocus = ValueNotifier<bool>(false);

  @override
  List<GridCellAccessory> Function(GridCellAccessoryBuildContext buildContext)? get accessoryBuilder => null;

  @override
  final GridCellFocusListener beginFocus = GridCellFocusListener();

  @override
  final Map<CellKeyboardKey, CellKeyboardAction> shortcutHandlers = {};
}

abstract class GridCellState<T extends GridCellWidget> extends State<T> {
  @override
  void initState() {
    widget.beginFocus.setListener(() => requestBeginFocus());
    widget.shortcutHandlers[CellKeyboardKey.onCopy] = () => onCopy();
    widget.shortcutHandlers[CellKeyboardKey.onInsert] = () {
      Clipboard.getData("text/plain").then((data) {
        final s = data?.text;
        if (s is String) {
          onInsert(s);
        }
      });
    };
    super.initState();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    if (oldWidget != this) {
      widget.beginFocus.setListener(() => requestBeginFocus());
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.beginFocus.removeAllListener();
    super.dispose();
  }

  void requestBeginFocus();

  String? onCopy() => null;

  void onInsert(String value) {}
}

abstract class GridFocusNodeCellState<T extends GridCellWidget> extends GridCellState<T> {
  SingleListenrFocusNode focusNode = SingleListenrFocusNode();

  @override
  void initState() {
    widget.shortcutHandlers[CellKeyboardKey.onEnter] = () => focusNode.unfocus();
    _listenOnFocusNodeChanged();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    if (oldWidget != this) {
      _listenOnFocusNodeChanged();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.shortcutHandlers.clear();
    focusNode.removeAllListener();
    focusNode.dispose();
    super.dispose();
  }

  @override
  void requestBeginFocus() {
    if (focusNode.hasFocus == false && focusNode.canRequestFocus) {
      FocusScope.of(context).requestFocus(focusNode);
    }
  }

  void _listenOnFocusNodeChanged() {
    widget.isFocus.value = focusNode.hasFocus;
    focusNode.setListener(() {
      widget.isFocus.value = focusNode.hasFocus;
      focusChanged();
    });
  }

  Future<void> focusChanged() async {}
}

class GridCellFocusListener extends ChangeNotifier {
  VoidCallback? _listener;

  void setListener(VoidCallback listener) {
    if (_listener != null) {
      removeListener(_listener!);
    }

    _listener = listener;
    addListener(listener);
  }

  void removeAllListener() {
    if (_listener != null) {
      removeListener(_listener!);
    }
  }

  void notify() {
    notifyListeners();
  }
}

abstract class GridCellStyle {}

class SingleListenrFocusNode extends FocusNode {
  VoidCallback? _listener;

  void setListener(VoidCallback listener) {
    if (_listener != null) {
      removeListener(_listener!);
    }

    _listener = listener;
    super.addListener(listener);
  }

  void removeAllListener() {
    if (_listener != null) {
      removeListener(_listener!);
    }
  }
}

class CellStateNotifier extends ChangeNotifier {
  bool _isFocus = false;
  bool _onEnter = false;

  set isFocus(bool value) {
    if (_isFocus != value) {
      _isFocus = value;
      notifyListeners();
    }
  }

  set onEnter(bool value) {
    if (_onEnter != value) {
      _onEnter = value;
      notifyListeners();
    }
  }

  bool get isFocus => _isFocus;

  bool get onEnter => _onEnter;
}

abstract class CellFocustable {
  GridCellFocusListener get beginFocus;
}

class CellContainer extends StatelessWidget {
  final GridCellWidget child;
  final AccessoryBuilder? accessoryBuilder;
  final double width;
  final RegionStateNotifier rowStateNotifier;
  const CellContainer({
    Key? key,
    required this.child,
    required this.width,
    required this.rowStateNotifier,
    this.accessoryBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<RegionStateNotifier, CellStateNotifier>(
      create: (_) => CellStateNotifier(),
      update: (_, row, cell) => cell!..onEnter = row.onEnter,
      child: Selector<CellStateNotifier, bool>(
        selector: (context, notifier) => notifier.isFocus,
        builder: (context, isFocus, _) {
          Widget container = Center(child: GridCellShortcuts(child: child));
          child.isFocus.addListener(() {
            Provider.of<CellStateNotifier>(context, listen: false).isFocus = child.isFocus.value;
          });

          if (accessoryBuilder != null) {
            final buildContext = GridCellAccessoryBuildContext(anchorContext: context);
            final accessories = accessoryBuilder!(buildContext);
            if (accessories.isNotEmpty) {
              container = CellEnterRegion(child: container, accessories: accessories);
            }
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => child.beginFocus.notify(),
            child: Container(
              constraints: BoxConstraints(maxWidth: width, minHeight: 46),
              decoration: _makeBoxDecoration(context, isFocus),
              padding: GridSize.cellContentInsets,
              child: container,
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _makeBoxDecoration(BuildContext context, bool isFocus) {
    final theme = context.watch<AppTheme>();
    if (isFocus) {
      final borderSide = BorderSide(color: theme.main1, width: 1.0);
      return BoxDecoration(border: Border.fromBorderSide(borderSide));
    } else {
      final borderSide = BorderSide(color: theme.shader5, width: 1.0);
      return BoxDecoration(border: Border(right: borderSide, bottom: borderSide));
    }
  }
}

class CellEnterRegion extends StatelessWidget {
  final Widget child;
  final List<GridCellAccessory> accessories;
  const CellEnterRegion({required this.child, required this.accessories, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<CellStateNotifier, bool>(
      selector: (context, notifier) => notifier.onEnter,
      builder: (context, onEnter, _) {
        List<Widget> children = [child];
        if (onEnter) {
          children.add(AccessoryContainer(accessories: accessories).positioned(right: 0));
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (p) => Provider.of<CellStateNotifier>(context, listen: false).onEnter = true,
          onExit: (p) => Provider.of<CellStateNotifier>(context, listen: false).onEnter = false,
          child: Stack(
            alignment: AlignmentDirectional.center,
            fit: StackFit.expand,
            children: children,
          ),
        );
      },
    );
  }
}