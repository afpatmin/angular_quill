import 'dart:async';
import 'dart:html' show Element;
import 'dart:js_util' show jsify;

import "package:js/js.dart" show allowInterop;
import 'package:ngdart/angular.dart';
import 'package:ngforms/angular_forms.dart';

import 'quill.dart' as quill;

@Component(
  selector: 'quill',
  templateUrl: 'quill_component.html',
)
class QuillComponent implements AfterContentInit, OnDestroy {
  quill.QuillStatic? quillEditor;

  @ViewChild('editor')
  Element? editor;

  String _initialValue = '';
  @Input()
  String placeholder = '';

  @Input()
  dynamic modules = {};

  bool _disabled = false;

  final StreamController _blur = new StreamController.broadcast();

  @Input()
  int? maxLength;
  final StreamController _focus = new StreamController();
  final StreamController _input = new StreamController.broadcast();

  var _selectionChangeSub;

  var _textChangeSub;

  @Output()
  Stream get blur => _blur.stream;

  bool get disabled => _disabled;
  @Input()
  set disabled(bool v) {
    _disabled = v;
    quillEditor?.enable(!v);
  }

  @Output()
  Stream get focus => _focus.stream;
  @Output()
  Stream get input => _input.stream;

  String get value {
    if (editor == null || editor!.children.isEmpty) {
      return '';
    } else {
      return editor!.children.first.innerHtml ?? '';
    }
  }

  @Input()
  set value(String val) {
    String v = val;
    if (quillEditor == null) {
      _initialValue = val;
    } else {
      quillEditor!.pasteHTML(v);
    }
  }

  @override
  ngAfterContentInit() {
    quillEditor = new quill.QuillStatic(
        editor,
        new quill.QuillOptionsStatic(
            theme: 'snow', placeholder: placeholder, modules: jsify(modules)));

    _textChangeSub = allowInterop(_onTextChange);
    _selectionChangeSub = allowInterop(_onSelectionChange);
    quillEditor!.on('text-change', _textChangeSub);
    quillEditor!.on('selection-change', _selectionChangeSub);

    quillEditor!.enable(!_disabled);
    quillEditor!.pasteHTML(_initialValue);
  }

  @override
  ngOnDestroy() {
    quillEditor?.off('text-change', _textChangeSub);
    quillEditor?.off('selection-change', _selectionChangeSub);

    // quill docs say no explicit destroy call is required.
  }

  /// Emitted when a user or API causes the selection to change, with a range representing the selection boundaries.
  ///
  /// When range changes from null value to non-null value, it indicates focus lost so we emit [blur] event.
  /// When range changes from non-null value to null value, it indicates gain of focus so we emit [focus] event.
  void _onSelectionChange(range, oldRange, String source) {
    if (oldRange != null && range == null) {
      // null range indicates blur event
      _blur.add(null);
    } else if (oldRange == null && range != null) {
      // change from null to non-null range indicates focus event
      _focus.add(null);
    }
  }

  /// Emitted when the contents of Quill have changed. Details of the change, representation of the editor contents
  /// before the change, along with the source of the change are provided. The source will be "user" if it originates from the users
  void _onTextChange(delta, oldDelta, source) {
    _input.add(value);
  }
}

@Directive(selector: 'quill[ngModel]', providers: const [
  const ExistingProvider.forToken(ngValueAccessor, QuillValueAccessor)
])
class QuillValueAccessor implements ControlValueAccessor<String>, OnDestroy {
  final QuillComponent _quill;
  late StreamSubscription _blurSub;
  late StreamSubscription _inputSub;

  TouchFunction onTouched = () {};
  ChangeFunction<String> onChange = (String _, {String? rawValue}) {};

  QuillValueAccessor(this._quill) {
    _inputSub = _quill.input.listen(_onInput);
    _blurSub = _quill.blur.listen(_onBlur);
  }

  @override
  ngOnDestroy() {
    _blurSub.cancel();
    _inputSub.cancel();
  }

  @override
  void onDisabledChanged(bool isDisabled) {
    _quill.disabled = isDisabled;
  }

  /// Set the function to be called when the control receives a change event.
  @override
  void registerOnChange(ChangeFunction<String> fn) {
    this.onChange = fn;
  }

  /// Set the function to be called when the control receives a touch event.
  @override
  void registerOnTouched(TouchFunction fn) {
    onTouched = fn;
  }

  /// Write a new value to the element.
  @override
  void writeValue(String obj) {
    _quill.value = obj;
  }

  void _onBlur(_) {
    onTouched();
  }

  void _onInput(_) {
    onChange(_quill.value);
  }
}
