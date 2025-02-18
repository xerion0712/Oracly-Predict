import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"
import {
  Account,
  Aptos,
  AptosConfig,
  Network,
  Ed25519PrivateKey
} from "@aptos-labs/ts-sdk";
import { secret } from '@aws-amplify/backend';


export const handler: Schema["Faucet"]["functionHandler"] = async (event) => {
  const { name } = event.arguments

  const config = new AptosConfig({ network: Network.TESTNET });
  const aptos = new Aptos(config);

  const privateKey = new Ed25519PrivateKey(
    `${secret('APTOS_MANAGED_KEY')}`
  );

  const account = Account.fromPrivateKey({
    privateKey
  })

  return `Hello, ${account.accountAddress}!`
}