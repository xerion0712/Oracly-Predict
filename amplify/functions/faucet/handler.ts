import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"
import {
  Account,
  Aptos,
  AptosConfig,
  Network,
  Ed25519PrivateKey
} from "@aptos-labs/ts-sdk";
// import { env } from '$amplify/env/Faucet';

export const handler: Schema["Faucet"]["functionHandler"] = async (event) => {
  const { name } = event.arguments

  console.log("hello1")

  const config = new AptosConfig({ network: Network.TESTNET });

  console.log("hello2")

  const aptos = new Aptos(config);

  console.log("hello3")

  const privateKey = new Ed25519PrivateKey(
    `${process.env.APTOS_MANAGED_KEY}`
  );

  console.log("hello4")

  const account = Account.fromPrivateKey({
    privateKey
  })

  return `Hello, ${account.accountAddress}!`
}