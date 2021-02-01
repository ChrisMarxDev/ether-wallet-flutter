import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class EthereumService {
  int chainId;
  String ethUrl;
  Client httpClient;
  Web3Client ethClient;

  static const ABIS_PATH = "assets/abis.json";
  static const ADDRESSES_PATH = "assets/addresses.json";
  static const NETWORK_NAMES = {
    1: "Mainnet",
    3: "Ropsten",
    4: "Rinkeby",
    42: "Kovan",
  };

  // IMPORTANT use http instead of wss infura endpoint, web3dart not supporting wss yet
  String get INFURA_URL =>
      'https://' +
      networkName +
      '.infura.io/v3/cf6ea736e00b4ee4bc43dfdb68f51093';

  EthereumService(this.chainId) {
    httpClient = new Client();
    ethClient = new Web3Client(INFURA_URL, httpClient);
  }

  Future<DeployedContract> loadTokenContract(String tokenName) async {
    String allAbis = await rootBundle.loadString(ABIS_PATH);

    final decodedAbis = jsonDecode(allAbis);
    final abiCode = jsonEncode(decodedAbis["token"]);
    final contractAddress = await getTokenAddr(tokenName);
    return DeployedContract(
        ContractAbi.fromJson(abiCode, tokenName), contractAddress);
  }

  Future<DeployedContract> loadContract(String contractName) async {
    String allAbis = await rootBundle.loadString(ABIS_PATH);
    final decodedAbis = jsonDecode(allAbis);
    final abiCode = jsonEncode(decodedAbis[contractName]);
    final contractAddress = await getContractAddress(contractName);
    return DeployedContract(
        ContractAbi.fromJson(abiCode, contractName), contractAddress);
  }

  String get networkName => NETWORK_NAMES[this.chainId];

  // will probably throw error since addresses is not complete
  Future<EthereumAddress> getContractAddress(String contractName) async {
    String allAddresses = await rootBundle.loadString(ADDRESSES_PATH);
    final decodedAddresses = jsonDecode(allAddresses);
    final hexAddress = decodedAddresses[contractName][chainId.toString()];
    return EthereumAddress.fromHex(hexAddress);
  }

  Future<EthereumAddress> getTokenAddr(String tokenName) async {
    String allAddresses = await rootBundle.loadString(ADDRESSES_PATH);
    final decodedAddresses = jsonDecode(allAddresses);
    final hexAddress = decodedAddresses["token"][tokenName][chainId.toString()];
    return EthereumAddress.fromHex(hexAddress);
  }

  Future<String> getTokenAddrHex(String tokenName) async {
    return (await getTokenAddr(tokenName)).hex;
  }

  Future<EtherAmount> getEtherBalance(Credentials credentials) async {
    return await ethClient.getBalance(await credentials.extractAddress());
  }

  /// submit a tx from the supplied [credentials]
  /// calls deploayed [contract] with the function [functionName] supplying all [args] in order of appearence in the api
  /// returns a [String] containing the tx hash which can be used to acquire further information about the tx
  Future<String> submit(Credentials credentials, DeployedContract contract,
      String functionName, List<dynamic> args, {EtherAmount value}) async {
    final ethFunction = contract.function(functionName);

    var result = await ethClient.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: ethFunction,
          parameters: args,
          value: value
        ),
        chainId: chainId);
    return result;
  }

  Future<List<dynamic>> query(DeployedContract contract, String functionName,
      List<dynamic> args) async {
    final ethFunction = contract.function(functionName);
    final data = await ethClient.call(
        contract: contract, function: ethFunction, params: args);
    return data;
  }

  // Function to get receipt
  Future<TransactionReceipt> getTransactionReceipt(String txHash) async {
    return await ethClient.getTransactionReceipt(txHash);
  }

  Future<Credentials> credentialsForKey(String privateKey) {
    return ethClient.credentialsFromPrivateKey(privateKey);
  }

// void addBlockListener(listener){
//   ethClient.addedBlocks(listener);
//   ethClient.
// }
}
