import 'package:etherwallet/service/deus/deus_swap_service_alt.dart';
import 'package:etherwallet/service/deus/ethereum_service.dart';
import 'package:flutter/material.dart';
import 'package:pointycastle/api.dart';

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  DeusSwapServiceAlt swapService;
  String allowance;
  String appovalHash;

  @override
  void initState() {
    super.initState();
    swapService = DeusSwapServiceAlt(
        ethService: EthereumService(4),
        privateKey:
            "0xbba655b0a39daea9270bbb15715c0574f1fe3409ab0b551c3fe90aace22225fc");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          children: [
            RaisedButton(
              child: Text("Get Allowance"),
              onPressed: () async {
                print("Allowance");
                await swapService
                    .getAllowances("deus")
                    .then((value) => setState(() {
                          allowance = value;
                        }));
                print("Allowance finished");
              },
            ),
            SelectableText(allowance ?? "Empty"),
            RaisedButton(
              child: Text("Approve"),
              onPressed: () async {
                print("Approve");
                await swapService
                    .approve("deus", BigInt.from(1000))
                    .then((value) => setState(() {
                          appovalHash = value;
                        }));
                print("Approve");
              },
            ),
            SelectableText(appovalHash ?? "Empty")
          ],
        ),
      ),
    );
  }

}
