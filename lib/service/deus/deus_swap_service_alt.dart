import 'dart:convert';
import 'dart:math';

import 'package:etherwallet/service/deus/ethereum_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

class DeusSwapServiceAlt {
  static const GRAPHBK_PATH = "assets/graphbk.json";
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

  EthereumService ethService;

  DeployedContract automaticMarketMakerContract;
  DeployedContract staticSalePrice;
  DeployedContract deusSwapContract;
  DeployedContract uniswapRouter;

  String privateKey;

  // will probably be a web3 PrivateKey
  // this.account = account;

  DeusSwapServiceAlt({@required this.ethService, @required this.privateKey}) {
    // TODO how to properly handle async stuff
    // all functions have to await initialization, maybe put await check in checkWallet
    _init();
  }

  _init() async {
    this.automaticMarketMakerContract = await ethService.loadContract("amm");
    this.staticSalePrice = await ethService.loadContract("sps");
    this.deusSwapContract = await ethService.loadContract("deus_swap_contract");
    this.uniswapRouter = await ethService.loadContract("uniswap_router");
  }

  Future<Credentials> get credentials =>
      ethService.credentialsForKey(privateKey);

  Future<EthereumAddress> get address async =>
      (await ethService.credentialsForKey(privateKey)).extractAddress();

  bool checkWallet() {
    return ethService != null && this.privateKey != null;
  }

  BigInt _getWei(BigInt amount, [String token = "eth"]) {
    var max =
        TOKEN_MAX_DIGITS.containsKey(token) ? TOKEN_MAX_DIGITS[token] : 18;
    // let value = typeof number === "string" ? parseFloat(number).toFixed(18) : number.toFixed(18)
    var ans = EtherAmount.fromUnitAndValue(EtherUnit.ether, amount)
        .getInWei
        .toString();
    ans = ans.substring(0, ans.length - (18 - max));
    return BigInt.parse(ans.toString());
  }

  String _fromWei(BigInt value, String token) {
    var max =
        TOKEN_MAX_DIGITS.containsKey(token) ? TOKEN_MAX_DIGITS[token] : 18;
    String ans = value.toString();

    while (ans.length < max) {
      ans = "0" + ans;
    }
    ans = ans.substring(0, ans.length - max) +
        "." +
        ans.substring(ans.length - max);
    if (ans[0] == ".") {
      ans = "0" + ans;
    }
    return ans;
  }

  Future<double> getTokenBalance(tokenName) async {
    if (!this.checkWallet()) return 0;

    if (tokenName == "eth") {
      return (await ethService.getEtherBalance(await credentials))
          .getInEther
          .toDouble();
    }
    final tokenContract = await ethService.loadContract("token");

    EthereumAddress address = await (await credentials).extractAddress();
    final result =
        await ethService.query(tokenContract, "balanceOf", [address]);
    return result.single;
  }

  Future<String> approve(String token, BigInt amount) async {
    if (!this.checkWallet()) return "0";

    // final tokenContract = await ethereumService.loadContract("token");
    final tokenContract = await ethService.loadTokenContract(token);
    var maxAmount = BigInt.from(pow(10, 20));
    amount = max(amount, maxAmount);

    final swapContractAddress =
        await ethService.getContractAddress("deus_swap_contract");
    final wei = _getWei(amount, token);
    final result = await ethService.submit(await credentials, tokenContract,
        "approve", [swapContractAddress, wei]);
    return result;
  }

  Future<String> getAllowances(String tokenName) async {
    if (!this.checkWallet()) return "0";
    if (tokenName == "eth") return "9999";

    final tokenContract = await ethService.loadTokenContract(tokenName);
    final swapContractAddress =
        await ethService.getContractAddress("deus_swap_contract");

    final result = await ethService.query(
        tokenContract, "allowance", [await address, swapContractAddress]);
    BigInt allowance = result.single;
    return _fromWei(allowance, tokenName);
  }

  swapTokens(fromToken, toToken, tokenAmount, listener) async {}

  getWithdrawableAmount() async {}

  withdrawPayment(listener) async {}

  getAmountsOut(fromToken, toToken, amountIn) async {
    if (!checkWallet()) return 0;

    var path = await _getPath(fromToken, toToken);

    if (ethService.getTokenAddr(fromToken) == ethService.getTokenAddr("deus") &&
        ethService.getTokenAddr(toToken) == ethService.getTokenAddr("eth")) {
      final result = await ethService.query(automaticMarketMakerContract,
          "calculateSaleReturn", [_getWei(amountIn, fromToken)]);

      return _fromWei(result.single as BigInt, toToken);
    } else if (ethService.getTokenAddr(fromToken) ==
            ethService.getTokenAddr("eth") &&
        ethService.getTokenAddr(toToken) == ethService.getTokenAddr("deus")) {
      final result = await ethService.query(automaticMarketMakerContract,
          "calculatePurchaseReturn", [_getWei(amountIn, fromToken)]);

      return _fromWei(result.single as BigInt, toToken);
    }

    if (path[0] == (await ethService.getTokenAddr("coinbase")).hex) {
      if (path.length < 3) {
        final result = await ethService.query(staticSalePrice,
            "calculateSaleReturn", [this._getWei(amountIn, fromToken)]);
        return this._fromWei(result[0], toToken);
      }

      path = path.sublist(1);

      if (path[1] == (await ethService.getTokenAddr("weth")).hex) {
        var tokenAmount = await ethService.query(staticSalePrice,
            "calculateSaleReturn", [this._getWei(amountIn, fromToken)]);
        var etherAmount = await ethService.query(automaticMarketMakerContract,
            "calculateSaleReturn", [tokenAmount.single]);
        path = path.sublist(1);
        if (path.length < 2) {
          return this._fromWei(etherAmount.single, toToken);
        } else {
          var amountsOut = await ethService.query(uniswapRouter,
              "getAmountsOut", [this._getWei(etherAmount.single, fromToken)]);
          return this._fromWei(amountsOut[amountsOut.length - 1], toToken);
        }
      } else {
        final etherAmount = await ethService.query(staticSalePrice,
            "calculateSaleReturn", [this._getWei(amountIn, fromToken)]);
        final amountsOut = await ethService.query(
            uniswapRouter, "getAmountsOut", [etherAmount[0], path.first]);
        return this._fromWei(amountsOut[amountsOut.length - 1], toToken);
      }
    } else if (path[path.length - 1] ==
        (await ethService.getTokenAddr("coinbase")).hex) {
      if (path.length < 3) {
        var tokenAmount = await ethService.query(staticSalePrice,
            "calculateSaleReturn", [this._getWei(amountIn, fromToken)]);
        return this._fromWei(tokenAmount[0], toToken);
      }
      path = path.sublist(0, path.length - 1);
      if (path[path.length - 2] ==
          (await ethService.getTokenAddr("weth")).hex) {
        if (path.length > 2) {
          path = path.sublist(0, path.length - 1);
          final amountOut = await _uniSwapAmountOut(amountIn, path, fromToken);
          final tokenAmount = await _ammPurchaseReturn(amountOut);
          final amountOutStatic =
              await _staticSalePricePurchaseReturn(tokenAmount);
          return _fromWei(amountOutStatic, toToken);
        } else {
          final tokenAmount = await _ammPurchaseReturn(amountIn, fromToken);
          final amountOut = await _staticSalePricePurchaseReturn(tokenAmount);
          return this._fromWei(amountOut, toToken);
        }
      } else {
        final amountsOut = await _uniSwapAmountOut(amountIn, path, fromToken);
        final tokenAmount = await _staticSalePricePurchaseReturn(amountsOut);
        return this._fromWei(tokenAmount, toToken);
      }
    } else {
      final deusAddress = (await ethService.getTokenAddr("deus")).hex;
      bool isDeusAddress(String element) => element == deusAddress;
      final indexOfDeus = path.firstWhere(isDeusAddress);
    }
  }

  Future<BigInt> _uniSwapAmountOut(BigInt amountIn, List<String> path,
      [String fromToken]) async {
    final computeAmountInt =
        fromToken != null ? this._getWei(amountIn, fromToken) : amountIn;
    final result = await ethService
        .query(uniswapRouter, "getAmountsOut", [computeAmountInt, path.first]);
    return result[0] as BigInt;
  }

  Future<BigInt> _ammPurchaseReturn(BigInt amountIn, [String fromToken]) async {
    final computeAmountInt =
        fromToken != null ? this._getWei(amountIn, fromToken) : amountIn;
    final result = await ethService.query(automaticMarketMakerContract,
        "calculatePurchaseReturn", [computeAmountInt]);
    return result[0] as BigInt;
  }

  Future<BigInt> _staticSalePricePurchaseReturn(BigInt amountIn,
      [String fromToken]) async {
    final computeAmountInt =
        fromToken != null ? this._getWei(amountIn, fromToken) : amountIn;
    final result = await ethService
        .query(staticSalePrice, "calculatePurchaseReturn", [computeAmountInt]);
    return result[0] as BigInt;
  }

  getAmountsIn(fromToken, toToken, amountOut) async {
    throw UnimplementedError("Source implementation missing");
  }

  approveStocks(BigInt amount, listener) async {
    if (!checkWallet()) return 0;

    final tokenContract = await ethService.loadTokenContract("dai");
    var maxAmount = BigInt.from(pow(10, 20));
    amount = max(amount, maxAmount);
    final wei = _getWei(amount, "ether");
    final result = await ethService.submit(
        await credentials,
        tokenContract,
        "approve",
        [await ethService.getContractAddress("stocks_contract"), wei]);
    return result;
  }

  getAllowancesStocks() async {
    if (!checkWallet()) return 0;

    final tokenContract = await ethService.loadTokenContract("dai");

    final result = await ethService.query(tokenContract, "allowance", [
      await address,
      await ethService.getContractAddress("stocks_contract")
    ]);

    return _fromWei(result.single, "dai");
  }

  buyStock(stockAddr, amount, blockNo, v, r, s, price, fee, listener) async {
    if (!checkWallet()) return 0;

    final stockContract = await ethService.loadContract("stocks_contract");

    final result = await ethService.submit(await credentials, stockContract,
        "buyStock", [stockAddr, amount, blockNo, v, r, s, price, fee]);
    return result;
  }

  sellStock(stockAddr, amount, blockNo, v, r, s, price, fee, listener) async {
    if (!checkWallet()) return 0;

    final stockContract = await ethService.loadContract("stocks_contract");

    final result = await ethService.submit(await credentials, stockContract,
        "sellStock", [stockAddr, amount, blockNo, v, r, s, price, fee]);
    return result;
  }

  Future<List<String>> _getPath(from, to) async {
    String allPaths = await rootBundle.loadString(GRAPHBK_PATH);
    final decodedPaths = jsonDecode(allPaths);
    return decodedPaths[from][to];
  }
}
