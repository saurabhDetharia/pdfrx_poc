import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pdf Viewer POC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'PDF Viewer Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // To handle PDF viewer
  final _controller = PdfViewerController();

  // List of annotation icons.
  final _annotationIcons = <int, List<Offset>>{};

  // Used to handle the text selection
  List<PdfTextRanges>? _textSelections;

  // List of highlights
  final _highlights = <int, List<PdfTextRanges>>{};

  // To enable/disable annotation mode.
  // If annotation mode is on, on tap of the
  // screen, annotations will be added.
  bool _isAnnotationModeOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          // Highlight icon
          _getHighLightIconWidget,
          // Annotations icon
          _getAnnotationIconWidget,
        ],
      ),
      body: PdfViewer.asset(
        'assets/sample.pdf',
        controller: _controller,
        params: PdfViewerParams(
          enableTextSelection: true,
          loadingBannerBuilder: _getLoadingViewWidget,
          viewerOverlayBuilder: _viewOverlayBuilder,
          pageOverlaysBuilder: _pageOverlayBuilder,
          onTextSelectionChange: _onTextSelectionChanges,
          pagePaintCallbacks: [
            // Highlight painter.
            _paintHighlights,
          ],
        ),
      ),
    );
  }

  /// This will be used to show an overlay over the PDF Viewer.
  List<Widget> _viewOverlayBuilder(
    BuildContext context,
    Size size,
    PdfViewerHandleLinkTap handleLinkTap,
  ) {
    // List of the tappable icons at the left side of highlighted texts.
    final tappableIcons = _getTappableIcons();

    return [
      // Detect tap events any where on the PDF Viewer.
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          handleLinkTap(details.localPosition);
        },
        onDoubleTap: () {
          // Used to zoom on double tapping the view.
          _controller.zoomUp();
        },
        child: IgnorePointer(
          child: SizedBox(width: size.width, height: size.height),
        ),
      ),

      ...tappableIcons,
    ];
  }

  /// Whenever text selection changes, it will be called
  /// to update the list selected texts.
  void _onTextSelectionChanges(List<PdfTextRanges> selections) {
    _textSelections = selections;
    setState(() {});
  }

  /// This will be shown while the pdfs are loading.
  Widget _getLoadingViewWidget(
    BuildContext context,
    int bytesDownloaded,
    int? totalBytes,
  ) {
    return Center(
      child: CircularProgressIndicator(
        value: totalBytes != null ? bytesDownloaded / totalBytes : null,
        color: Colors.white,
      ),
    );
  }

  /// This will be used to show the Highlighter icon
  Widget get _getHighLightIconWidget {
    return IconButton(
      onPressed: () {
        _highlightSelectedText();
      },
      icon: Icon(Icons.circle),
      color:
          (_textSelections == null || (_textSelections?.isEmpty ?? true)
              ? Colors.grey
              : Colors.red),
    );
  }

  /// This will be used to show the Annotations icon
  Widget get _getAnnotationIconWidget {
    return IconButton(
      onPressed: () {
        setState(() {
          _isAnnotationModeOn = !_isAnnotationModeOn;
        });
      },
      icon: Icon(
        Icons.comment,
        color: _isAnnotationModeOn ? Colors.black : Colors.grey,
      ),
    );
  }

  /// This will be used to highlight the text,
  /// only if the text are selected
  void _highlightSelectedText() {
    // Checks whether the text are selected or not.
    if (_textSelections != null && _textSelections!.isNotEmpty) {
      // Add all selected texts to the markers list.
      for (final selectedText in _textSelections!) {
        _highlights
            .putIfAbsent(selectedText.pageNumber, () => [])
            .add(selectedText);
      }
      setState(() {});
    }
  }

  /// This will be used to paint over highlights.
  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    // Gets highlights of the provided page.
    final highlightsByPage = _highlights[page.pageNumber];

    // Prevents further drawing if no highlights found.
    if (highlightsByPage != null && highlightsByPage.isNotEmpty) {
      // Defines properties for the painter.
      final paint =
          Paint()
            ..color = Colors.red.withAlpha(100)
            ..style = PaintingStyle.fill;

      for (final highlights in highlightsByPage) {
        for (final range in highlights.ranges) {
          // Gets fragments from the text.
          final fragments = PdfTextRangeWithFragments.fromTextRange(
            highlights.pageText,
            range.start,
            range.end,
          );

          if (fragments != null) {
            canvas.drawRect(
              fragments.bounds.toRectInPageRect(page: page, pageRect: pageRect),
              paint,
            );
          }
        }
      }
    }
  }

  /// This will be used to show the icons before the
  /// highlight starts.
  List<Widget> _getTappableIcons() {
    final tappableIcons = <Widget>[];

    for (final highlights in _highlights.values) {
      for (final highlight in highlights) {
        // Convert in-page => document
        final rectInsidePage = _controller.calcRectForRectInsidePage(
          pageNumber: highlight.pageNumber,
          rect: highlight.bounds,
        );

        // Convert Document => Flutter's global
        final globalTopLeft = _controller.documentToGlobal(
          rectInsidePage.topLeft,
        );

        final localTopLeft = _controller.globalToLocal(globalTopLeft!);

        tappableIcons.add(
          Positioned(
            left: localTopLeft!.dx - (16 * _controller.currentZoom),
            top: localTopLeft.dy,
            child: GestureDetector(
              onTap: () {},
              child: Icon(
                Icons.square,
                color: Colors.red,
                size: 16 * _controller.currentZoom,
              ),
            ),
          ),
        );
      }
    }

    return tappableIcons;
  }

  /// This will be used to show the icons before the
  /// highlight starts.
  List<Widget> _getAnnotationIcons(int pageNumber) {
    final tappableIcons = <Widget>[];

    for (final annotations in _annotationIcons.entries) {
      if (annotations.key == pageNumber) {
        for (final annotation in annotations.value) {
          tappableIcons.add(
            Positioned(
              left: annotation.dx * _controller.currentZoom,
              top: annotation.dy * _controller.currentZoom,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPressEnd: (d) {
                  print('test tapped');
                },
                child: Icon(
                  Icons.info,
                  color: Colors.green,
                  size: 16 * _controller.currentZoom,
                ),
              ),
            ),
          );
        }
      }
    }

    return tappableIcons;
  }

  List<Widget> _pageOverlayBuilder(
    BuildContext context,
    Rect pageRect,
    PdfPage page,
  ) {
    // List of the icons at where the user tapped.
    final annotatedIcons = _getAnnotationIcons(page.pageNumber);

    final annotationTapWidget = GestureDetector(
      onLongPressEnd:
          !_isAnnotationModeOn
              ? null
              : (details) {
                // Disable annotation mode.
                _isAnnotationModeOn = false;

                // Add the coordinates to the list.
                setState(() {
                  _annotationIcons
                      .putIfAbsent(page.pageNumber, () => [])
                      .add(details.localPosition / _controller.currentZoom);
                });
              },
    );

    return [
      // To add annotations
      annotationTapWidget,

      // List of annotations
      ...annotatedIcons,

      // Static position
      Positioned(
        left: 50 * _controller.currentZoom,
        top: 50 * _controller.currentZoom,
        child: Container(
          height: 10 * _controller.currentZoom,
          width: 10 * _controller.currentZoom,
          color: Colors.green,
        ),
      ),
    ];
  }
}
