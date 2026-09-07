import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/app_theme.dart';
import '../../services/order_service.dart';

/// Loads the Stripe-hosted checkout page. Watches for the return/cancel
/// redirect URLs, then polls the backend for the payment's real status —
/// the browser redirect alone is never trusted, only the webhook-backed
/// status endpoint. Returns true (paid), false (cancelled/failed), or null
/// (customer backed out without a clear result) via Navigator.pop.
class CardPaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final int paymentId;

  const CardPaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.paymentId,
  });

  @override
  State<CardPaymentWebViewScreen> createState() => _CardPaymentWebViewScreenState();
}

class _CardPaymentWebViewScreenState extends State<CardPaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _confirming = false;
  bool _loadingPage = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loadingPage = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loadingPage = false);
          },
          onNavigationRequest: (request) {
            if (request.url.contains('/api/stripe-return/')) {
              _handleReturnedFromCheckout();
              return NavigationDecision.navigate;
            }
            if (request.url.contains('/api/stripe-cancel/')) {
              Navigator.pop(context, false);
              return NavigationDecision.navigate;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<void> _handleReturnedFromCheckout() async {
    if (_confirming) return;
    setState(() => _confirming = true);

    // The webhook may take a moment to arrive and process — poll briefly
    // rather than trusting the redirect itself.
    for (int attempt = 0; attempt < 8; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      final status = await OrderService.getPaymentStatus(widget.paymentId);
      if (!mounted) return;

      if (status == 'COMPLETED') {
        Navigator.pop(context, true);
        return;
      }
      if (status == 'FAILED') {
        Navigator.pop(context, false);
        return;
      }
      // still PENDING — keep polling
    }

    if (!mounted) return;
    // Gave up waiting — don't claim success. The webhook may still land
    // shortly after; the order will simply show as paid once it does.
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: _confirming
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Confirming your payment...', style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loadingPage) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}