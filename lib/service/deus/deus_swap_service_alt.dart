import 'dart:math';

import 'package:etherwallet/service/deus/ethereum_service.dart';
import 'package:web3dart/web3dart.dart';

class DeusSwapServiceAlt {
  static const TOKEN_MAX_DIGITS = {
    "wbtc": 8,
    "usdt": 6,
    "usdc": 6,
    "coinbase": 18,
    "dea": 18,
    "deus": 18,
    "dai": 18,
    "eth": 18,
  };

  EthereumService ethereumService;

  DeployedContract automaticMarketMakerContract;
  DeployedContract staticSalePrice;
  DeployedContract deusSwapContract;
  DeployedContract uniswapRouter;

  Credentials account;

  // will probably be a web3 PrivateKey
  // this.account = account;

  DeusSwapServiceAlt({this.ethereumService, this.account}) {
    // TODO how to properly handle async stuff
    // all functions have to await initialization, maybe put await check in checkWallet
    _init();
  }

  _init() async {
    this.automaticMarketMakerContract =
        await ethereumService.loadContract("amm");
    this.staticSalePrice = await ethereumService.loadContract("sps");
    this.deusSwapContract =
        await ethereumService.loadContract("deus_swap_contract");
    this.uniswapRouter = await ethereumService.loadContract("uniswap_router");
  }

  bool checkWallet() {
    return this.account != null && ethereumService != null;
  }

  String _getWei(double amount, {String token = "eth"}) {
    var max =
        TOKEN_MAX_DIGITS.containsKey(token) ? TOKEN_MAX_DIGITS[token] : 18;
    // let value = typeof number === "string" ? parseFloat(number).toFixed(18) : number.toFixed(18)
    var ans = EtherAmount.fromUnitAndValue(EtherUnit.ether, amount)
        .getInWei
        .toString();
    ans = ans.substring(0, ans.length - (18 - max));
    return ans.toString();
  }

  String _fromWei(String value, String token) {
    var max =
        TOKEN_MAX_DIGITS.containsKey(token) ? TOKEN_MAX_DIGITS[token] : 18;
    var ans;

    while (ans.length < max) {
      ans = "0" + ans;
    }
    ans = ans.substr(0, ans.length - max) + "." + ans.substr(ans.length - max);
    if (ans[0] == ".") {
      ans = "0" + ans;
    }
    return ans;
  }

  Future<double> getTokenBalance(tokenName) async {
    if (!this.checkWallet()) return 0;

    if (tokenName == "eth") {
      return (await ethereumService.getEtherBalance(account))
          .getInEther
          .toDouble();
    }
    final tokenContract = await ethereumService.loadContract("token");

    EthereumAddress address = await account.extractAddress();
    final result =
        await ethereumService.query(tokenContract, "balanceOf", [address]);
    return result[0];
  }

  Future<String> approve(String token, double amount, listener) async {
    if (!this.checkWallet()) return "0";

    final tokenContract = await ethereumService.loadContract("token");
    amount = max(amount, pow(10, 20));

    final swapContractAddress =
        await ethereumService.getContractAddress("deus_swap_contract");
    final wei = _getWei(amount, token: token);
    final result = await ethereumService
        .submit(account, tokenContract, "approve", [swapContractAddress, wei]);
    return result;

    // tx handling has to be changed, can't use socket based handling that is used on the web app

    // return TokenContract.methods.approve(
    //     this.getAddr("deus_swap_contract"), this._getWei(amount, token))
    //     .send({ from: this.account})
    //     .once('transactionHash', () => listener("transactionHash"))
    //     .once('receipt', () => listener("receipt"))
    //     .once('error', () => listener("error"));
  }

  Future<String> getAllowances(String tokenName) async {
    if (!this.checkWallet()) return "0";
    if (tokenName == "eth") return "9999";

    final tokenContract = await ethereumService.loadContract("token");
    final swapContractAddress =
        await ethereumService.getContractAddress("deus_swap_contract");

    final result = await ethereumService
        .query(tokenContract, "allowance", [swapContractAddress]);
    return _fromWei(result[0], tokenName);
  }
}
