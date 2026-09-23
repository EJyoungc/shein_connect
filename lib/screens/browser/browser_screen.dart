import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_windows/webview_windows.dart' as ww;

import '../../models/cart_item_model.dart';
import '../../services/cart_service.dart';
import '../../utils/app_theme.dart';
import 'product_capture_modal.dart';

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;

  const BrowserScreen({super.key, this.initialUrl});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  static const String _defaultSheinUrl = 'https://m.shein.com';

  final TextEditingController _urlController = TextEditingController();

  // Mobile WebViewController (used on Android & iOS)
  wf.WebViewController? _mobileController;

  // Windows in-app WebViewController (used on Windows Desktop)
  ww.WebviewController? _windowsController;
  bool _isWindowsInitialized = false;
  bool _canGoBack = false;
  bool _canGoForward = false;

  bool _isLoading = true;
  double _progress = 0.0;
  String _currentUrl = _defaultSheinUrl;
  String _pageTitle = 'SHEIN Official Online Store';

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl ?? _defaultSheinUrl;
    _urlController.text = _currentUrl;

    if (_isMobile) {
      _initMobileWebview();
    } else if (_isWindows) {
      _initWindowsWebview();
    } else {
      _isLoading = false;
    }
  }

  void _initMobileWebview() {
    _mobileController = wf.WebViewController()
      ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        wf.NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
                _urlController.text = url;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              final title = await _mobileController?.getTitle();
              setState(() {
                _isLoading = false;
                _currentUrl = url;
                _urlController.text = url;
                if (title != null && title.isNotEmpty) {
                  _pageTitle = title;
                }
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  Future<void> _initWindowsWebview() async {
    try {
      final controller = ww.WebviewController();
      _windowsController = controller;

      await controller.initialize();
      await controller.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      );

      controller.url.listen((url) {
        if (mounted) {
          setState(() {
            _currentUrl = url;
            _urlController.text = url;
          });
        }
      });

      controller.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = (state == ww.LoadingState.loading);
          });
        }
      });

      controller.title.listen((title) {
        if (mounted && title.isNotEmpty) {
          setState(() {
            _pageTitle = title;
          });
        }
      });

      controller.historyChanged.listen((history) {
        if (mounted) {
          setState(() {
            _canGoBack = history.canGoBack;
            _canGoForward = history.canGoForward;
          });
        }
      });

      await controller.loadUrl(_currentUrl);

      if (mounted) {
        setState(() {
          _isWindowsInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing Windows in-app WebView: $e');
      if (mounted) {
        setState(() {
          _isWindowsInitialized = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    if (_isWindows) {
      _windowsController?.dispose();
    }
    super.dispose();
  }

  void _loadUrl(String inputUrl) {
    var url = inputUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        // Search on Shein
        url = 'https://m.shein.com/pdsearch/${Uri.encodeComponent(url)}';
      }
    }

    setState(() {
      _currentUrl = url;
      _urlController.text = url;
      _isLoading = true;
    });

    if (_isMobile && _mobileController != null) {
      _mobileController!.loadRequest(Uri.parse(url));
    } else if (_isWindows && _isWindowsInitialized && _windowsController != null) {
      _windowsController!.loadUrl(url);
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Core JavaScript extractor to capture product data from the live Shein page
  Future<void> _captureProductDetails() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Capturing product details from Shein...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // JavaScript to extract product attributes from Shein
    const jsExtractor = '''
      (function() {
        try {
          var title = "";
          var metaTitle = document.querySelector('meta[property="og:title"]');
          if (metaTitle && metaTitle.content) {
            title = metaTitle.content;
          } else {
            var h1 = document.querySelector('h1.product-intro__head-name, .goods-title, h1');
            if (h1) title = h1.innerText.trim();
            else title = document.title;
          }

          var price = "";
          var metaPrice = document.querySelector('meta[property="product:price:amount"], meta[property="og:price:amount"]');
          if (metaPrice && metaPrice.content) {
            price = "\$" + metaPrice.content;
          } else {
            var priceElem = document.querySelector('.goods-price, .product-intro__head-price, .original-price, .from, [class*="price"]');
            if (priceElem) price = priceElem.innerText.trim();
          }

          var image = "";
          var metaImg = document.querySelector('meta[property="og:image"]');
          if (metaImg && metaImg.content) {
            image = metaImg.content;
          } else {
            var imgElem = document.querySelector('.goods-img, img[src*="shein"], .swiper-slide-active img');
            if (imgElem) image = imgElem.src;
          }

          var color = "";
          var colorElem = document.querySelector('.goods-color__name, .color-select .active, [class*="color"]');
          if (colorElem) color = colorElem.innerText.trim();

          var desc = "";
          var metaDesc = document.querySelector('meta[name="description"], meta[property="og:description"]');
          if (metaDesc && metaDesc.content) desc = metaDesc.content;

          return JSON.stringify({
            url: window.location.href,
            name: title || "Shein Fashion Item",
            price: price || "\$19.99",
            imageUrl: image || "",
            variation: color ? ("Color: " + color) : "Standard",
            description: desc || ""
          });
        } catch(e) {
          return JSON.stringify({
            url: window.location.href,
            name: document.title,
            price: "\$19.99",
            imageUrl: "",
            variation: "Standard",
            description: ""
          });
        }
      })();
    ''';

    CartItem? capturedItem;

    if (_isMobile && _mobileController != null) {
      try {
        final result = await _mobileController!.runJavaScriptReturningResult(jsExtractor);
        final rawString = result.toString();
        // Remove surrounding quotes if double-encoded
        String jsonClean = rawString;
        if (jsonClean.startsWith('"') && jsonClean.endsWith('"')) {
          jsonClean = jsonDecode(jsonClean);
        }
        final Map<String, dynamic> data = jsonDecode(jsonClean);
        capturedItem = _buildCartItemFromMap(data);
      } catch (e) {
        debugPrint('Mobile JS extraction error: $e');
      }
    } else if (_isWindows && _isWindowsInitialized && _windowsController != null) {
      try {
        final result = await _windowsController!.executeScript(jsExtractor);
        Map<String, dynamic>? data;
        if (result is Map) {
          data = Map<String, dynamic>.from(result);
        } else if (result is String) {
          String jsonClean = result;
          if (jsonClean.startsWith('"') && jsonClean.endsWith('"')) {
            jsonClean = jsonDecode(jsonClean);
          }
          data = jsonDecode(jsonClean);
        }
        if (data != null) {
          capturedItem = _buildCartItemFromMap(data);
        }
      } catch (e) {
        debugPrint('Windows in-app JS extraction error: $e');
      }
    } else {
      try {
        capturedItem = await _scrapeProductHttp(_currentUrl);
      } catch (e) {
        debugPrint('Desktop scrape error: $e');
      }
    }

    // Fallback if scraping didn't produce data
    capturedItem ??= _buildFallbackItem(_currentUrl);
    // End of extraction block
    if (!mounted) return;

    // Show capture modal
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductCaptureModal(initialData: capturedItem!),
    );

    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Product successfully added to Shein Proc Cart!'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  CartItem _buildCartItemFromMap(Map<String, dynamic> data) {
    final priceStr = data['price']?.toString() ?? '\$19.99';
    final rawPrice = CartItem.parsePriceToNumber(priceStr);
    return CartItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      url: data['url']?.toString() ?? _currentUrl,
      name: data['name']?.toString() ?? 'Shein Product',
      price: priceStr,
      numericPrice: rawPrice > 0 ? rawPrice : 19.99,
      imageUrl: (data['imageUrl']?.toString().isNotEmpty ?? false) ? data['imageUrl'] : null,
      variation: data['variation']?.toString() ?? 'Color: Multi / Standard',
      description: data['description']?.toString() ?? 'Shein procurement item.',
    );
  }

  CartItem _buildFallbackItem(String url) {
    final uri = Uri.tryParse(url);
    String detectedName = _pageTitle;
    if (detectedName.contains('SHEIN') && detectedName.length > 10) {
      detectedName = detectedName.split('|').first.split('-').first.trim();
    }
    if (detectedName.isEmpty || detectedName == 'SHEIN Official Online Store') {
      final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
      if (segments.isNotEmpty) {
        detectedName = segments.last.replaceAll(RegExp(r'[-_]'), ' ').replaceAll('.html', '');
      } else {
        detectedName = 'Shein Trending Product';
      }
    }

    return CartItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      url: url,
      name: detectedName,
      price: '\$18.50',
      numericPrice: 18.50,
      variation: 'Color: Default / Size: M',
      description: 'Imported from Shein Online Store',
    );
  }

  /// Attempts to fetch product title, price, and image via HTTP when on Desktop / fallback
  Future<CartItem?> _scrapeProductHttp(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (!url.startsWith('http://') && !url.startsWith('https://'))) {
        return null;
      }
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final html = response.body;

        // Extract og:title or <title>
        String? title;
        final titleMatch = RegExp(
          r'<meta\s+property=["\x27]og:title["\x27]\s+content=["\x27](.*?)["\x27]',
          caseSensitive: false,
        ).firstMatch(html);
        if (titleMatch != null) {
          title = titleMatch.group(1);
        } else {
          final tMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
          title = tMatch?.group(1);
        }

        // Extract og:image
        String? imageUrl;
        final imgMatch = RegExp(
          r'<meta\s+property=["\x27]og:image["\x27]\s+content=["\x27](.*?)["\x27]',
          caseSensitive: false,
        ).firstMatch(html);
        if (imgMatch != null) {
          imageUrl = imgMatch.group(1);
        }

        // Extract price
        String price = '\$19.99';
        final priceMatch = RegExp(
          r'<meta\s+property=["\x27]product:price:amount["\x27]\s+content=["\x27](.*?)["\x27]',
          caseSensitive: false,
        ).firstMatch(html);
        if (priceMatch != null) {
          price = '\$${priceMatch.group(1)}';
        }

        if (title != null && title.trim().isNotEmpty) {
          var cleanTitle = title.trim();
          if (cleanTitle.contains('|')) cleanTitle = cleanTitle.split('|').first.trim();
          if (cleanTitle.contains('- SHEIN')) cleanTitle = cleanTitle.replaceAll('- SHEIN', '').trim();
          final rawPrice = CartItem.parsePriceToNumber(price);
          return CartItem(
            id: 'item_${DateTime.now().millisecondsSinceEpoch}',
            url: url,
            name: cleanTitle.isNotEmpty ? cleanTitle : 'Shein Fashion Item',
            price: price,
            numericPrice: rawPrice > 0 ? rawPrice : 19.99,
            imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
            variation: 'Color: Default / Size: Standard',
            description: 'Captured Shein product from link.',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Launch external browser (Chrome / Edge / Safari)
  Future<void> _openCurrentUrlInExternalBrowser([String? targetUrl]) async {
    final url = targetUrl ?? _currentUrl;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Dialog to manually paste any Shein link
  void _showPasteLinkDialog() {
    final pasteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.link, color: AppTheme.sheinCoral),
              SizedBox(width: 8),
              Text('Paste Shein Link', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste any Shein product link to open it or capture directly into your cart.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pasteController,
                decoration: const InputDecoration(
                  hintText: 'https://shein.com/product-link...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlack,
                minimumSize: const Size(90, 40),
              ),
              onPressed: () {
                final link = pasteController.text.trim();
                Navigator.of(ctx).pop();
                if (link.isNotEmpty) {
                  _loadUrl(link);
                }
              },
              child: const Text('Open & Browse'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 1,
          titleSpacing: 12,
          title: Row(
            children: [
              // Home button
              IconButton(
                icon: const Icon(Icons.home_outlined, size: 22),
                tooltip: 'Shein Home',
                onPressed: () => _loadUrl(_defaultSheinUrl),
              ),
              // Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                tooltip: 'Back',
                onPressed: () async {
                  if (_isMobile && (await _mobileController?.canGoBack() ?? false)) {
                    _mobileController?.goBack();
                  } else if (_isWindows && _isWindowsInitialized && _canGoBack) {
                    _windowsController?.goBack();
                  }
                },
              ),
              // Forward Button
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                tooltip: 'Forward',
                onPressed: () async {
                  if (_isMobile && (await _mobileController?.canGoForward() ?? false)) {
                    _mobileController?.goForward();
                  } else if (_isWindows && _isWindowsInitialized && _canGoForward) {
                    _windowsController?.goForward();
                  }
                },
              ),
              // URL input field
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 14, color: AppTheme.successGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Search or paste Shein URL',
                          ),
                          onSubmitted: _loadUrl,
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        InkWell(
                          onTap: () {
                            if (_isMobile && _mobileController != null) {
                              _mobileController?.reload();
                            } else if (_isWindows && _isWindowsInitialized && _windowsController != null) {
                              _windowsController?.reload();
                            }
                          },
                          child: const Icon(Icons.refresh, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Paste link quick tool
              IconButton(
                icon: const Icon(Icons.paste_rounded, size: 20, color: AppTheme.sheinCoral),
                tooltip: 'Paste Shein Link',
                onPressed: _showPasteLinkDialog,
              ),
              if (!_isMobile)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20, color: AppTheme.sheinCoral),
                  tooltip: 'Open in Browser',
                  onPressed: () => _openCurrentUrlInExternalBrowser(),
                ),
            ],
          ),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    color: AppTheme.sheinCoral,
                    backgroundColor: Colors.transparent,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
      ),
      body: Stack(
        children: [
          // In-App Webview
          if (_isMobile && _mobileController != null)
            wf.WebViewWidget(controller: _mobileController!)
          else if (_isWindows)
            if (_isWindowsInitialized && _windowsController != null)
              ww.Webview(_windowsController!)
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.sheinCoral),
                    SizedBox(height: 16),
                    Text(
                      'Loading Shein in-app browser...',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
          else
            _buildDesktopOrFallbackBrowser(),

          // Bottom Floating Action Bar for Product Capture
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildCaptureFloatingBar(),
          ),
        ],
      ),
    );
  }

  /// Handsome floating bar with 1-tap "Capture Product / Add to Cart"
  Widget _buildCaptureFloatingBar() {
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlack.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Shein Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.sheinCoral,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SHEIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Active Page / Capture Label
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pageTitle.isNotEmpty ? _pageTitle : 'Browsing Shein',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Tap to extract name, price, variation & link',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Primary "Capture & Add to Cart" Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.sheinCoral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text(
                  'Capture to Cart',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _captureProductDetails,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fallback / Desktop Browser interface when native webview runtime initializes
  Widget _buildDesktopOrFallbackBrowser() {
    return Container(
      color: const Color(0xFFF7F7F8),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.travel_explore,
                  size: 40,
                  color: AppTheme.sheinCoral,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Shein In-App Shopping Browser',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Browse and capture Shein products with automatic name, link, price, and variation extraction into your local cart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Category Shortcuts
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickPill('👗 Women Fashion', 'https://m.shein.com/women-fashion-c-1727.html'),
                  _buildQuickPill('👔 Men Collection', 'https://m.shein.com/men-c-1970.html'),
                  _buildQuickPill('👠 Shoes & Bags', 'https://m.shein.com/shoes-c-1748.html'),
                  _buildQuickPill('✨ Curve & Plus', 'https://m.shein.com/curve-c-1937.html'),
                  _buildQuickPill('🔥 Flash Sale', 'https://m.shein.com/flashsale.html'),
                ],
              ),
              const SizedBox(height: 24),

              // Active Target URL & External Browser Action Card
              Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language, color: AppTheme.sheinCoral, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.sheinCoral),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.open_in_browser, size: 16, color: AppTheme.sheinCoral),
                            label: const Text('Open in Browser', style: TextStyle(color: AppTheme.sheinCoral, fontSize: 12)),
                            onPressed: () => _openCurrentUrlInExternalBrowser(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlack,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('Capture Page', style: TextStyle(fontSize: 12)),
                            onPressed: _captureProductDetails,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Test Capture Card for instant preview
              Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt, color: AppTheme.sheinCoral, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Instant Shein Product Test & Capture',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try capturing sample Shein items directly to verify local cart capture:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    _buildSampleProductTile(
                      name: 'Letter Graphic Drop Shoulder Thermal Sweatshirt',
                      price: '\$14.49',
                      numeric: 14.49,
                      url: 'https://m.shein.com/Letter-Graphic-Drop-Shoulder-Thermal-Sweatshirt-p-1294821.html',
                      variation: 'Color: Heather Gray / Size: M',
                      imageUrl: 'https://img.ltwebstatic.com/images3_pi/2022/10/24/1666579622d057da00f73f6087d853ba36efee4ee5_thumbnail_750x999.webp',
                    ),
                    const SizedBox(height: 10),
                    _buildSampleProductTile(
                      name: 'Solid Pocket Patched Drop Shoulder Corduroy Shirt',
                      price: '\$19.99',
                      numeric: 19.99,
                      url: 'https://m.shein.com/Solid-Pocket-Patched-Corduroy-Shirt-p-1849201.html',
                      variation: 'Color: Navy Blue / Size: L',
                      imageUrl: 'https://img.ltwebstatic.com/images3_pi/2023/09/14/06/16946765798939c3cb941e739228d49a7c36a3f3b4_thumbnail_750x999.webp',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 70), // Spacing for floating bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPill(String label, String targetUrl) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () => _loadUrl(targetUrl),
    );
  }

  Widget _buildSampleProductTile({
    required String name,
    required String price,
    required double numeric,
    required String url,
    required String variation,
    required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.lightGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 44,
              height: 44,
              color: Colors.grey.shade300,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$price  •  $variation',
                  style: const TextStyle(fontSize: 11, color: AppTheme.sheinCoral),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlack,
              minimumSize: const Size(64, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final item = CartItem(
                id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
                url: url,
                name: name,
                price: price,
                numericPrice: numeric,
                imageUrl: imageUrl,
                variation: variation,
                description: 'Imported high demand fashion item from Shein.',
              );
              final added = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ProductCaptureModal(initialData: item),
              );
              if (added == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item added to local cart!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: const Text('Capture', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
