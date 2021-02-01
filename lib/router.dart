import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';

import 'context/setup/wallet_setup_provider.dart';
import 'context/transfer/wallet_transfer_provider.dart';
import 'context/wallet/wallet_provider.dart';
import 'presentation/screens/intro_page.dart';
import 'presentation/screens/wallet_create_page.dart';
import 'presentation/screens/wallet_import_page.dart';
import 'presentation/screens/wallet_main_page.dart';
import 'presentation/screens/wallet_market.dart';
import 'presentation/screens/test_screen.dart';
import 'presentation/screens/wallet_transfer_page.dart';
import 'presentation/screens/qrcode_reader_page.dart';
import 'service/configuration_service.dart';

Map<String, WidgetBuilder> getRoutes(context) {
  return {
    '/': (BuildContext context) {
      var configurationService = Provider.of<ConfigurationService>(context);
      if (configurationService.didSetupWallet())
        return WalletProvider(builder: (context, store) {
          return WalletMainPage("Your wallet");
        });

      return IntroPage();
    },
    '/create': (BuildContext context) =>
        WalletSetupProvider(builder: (context, store) {
          useEffect(() {
            store.generateMnemonic();
            return null;
          }, []);

          return WalletCreatePage("Create wallet");
        }),
    '/import': (BuildContext context) => WalletSetupProvider(
          builder: (context, store) {
            return WalletImportPage("Import wallet");
          },
        ),
    '/transfer': (BuildContext context) => WalletTransferProvider(
          builder: (context, store) {
            return WalletTransferPage(title: "Send Tokens");
          },
        ),
    '/market': (BuildContext context) => WalletTransferProvider(
          builder: (_, __) => MarketScreen(),
        ),
    '/qrcode_reader': (BuildContext context) => QRCodeReaderPage(
          title: "Scan QRCode",
          onScanned: ModalRoute.of(context).settings.arguments,
        ),
    '/test': (BuildContext context) => TestScreen()
  };
}
