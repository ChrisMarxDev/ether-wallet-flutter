import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../components/wallet/confirm_mnemonic.dart';
import '../components/wallet/display_mnemonic.dart';
import '../../context/setup/wallet_setup_provider.dart';
import '../../model/wallet_setup.dart';

class WalletCreatePage extends HookWidget {
  WalletCreatePage(this.title);

  final String title;

  Widget build(BuildContext context) {
    var store = useWalletSetup(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: store.state.step == WalletCreateSteps.display
          ? DisplayMnemonic(
              mnemonic: store.state.mnemonic,
              onNext: () async {
                store.goto(WalletCreateSteps.confirm);
              },
            )
          : ConfirmMnemonic(
              mnemonic: store.state.mnemonic,
              errors: store.state.errors.toList(),
              onConfirm: !store.state.loading
                  ? (confirmedMnemonic) async {
                      if (await store.confirmMnemonic(confirmedMnemonic)) {
                        Navigator.of(context).popAndPushNamed("/");
                      }
                    }
                  : null,
              onGenerateNew: !store.state.loading
                  ? () async {
                      store.generateMnemonic();
                      store.goto(WalletCreateSteps.display);
                    }
                  : null,
            ),
    );
  }
}
