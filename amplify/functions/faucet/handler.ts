import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"
import {
  Account,
  Aptos,
  AptosConfig,
  Network,
  Ed25519PrivateKey
} from "@aptos-labs/ts-sdk";

export const handler: Schema["Faucet"]["functionHandler"] = async (event) => {
  const { name } = event.arguments

  const config = new AptosConfig({ network: Network.TESTNET });

  const aptos = new Aptos(config);

  const privateKey = new Ed25519PrivateKey(
    `${process.env.APTOS_MANAGED_KEY}`
  );

  const account = Account.fromPrivateKey({
    privateKey
  })

  const transaction = await aptos.transaction.build.simple({
    sender: account.accountAddress,
    data: {
      function: `0xab3922ccb1794928abed8f5a5e8d9dac72fed24f88077e46593bed47dcdb7775::mock_usdc_fa::mint`,
      functionArguments: [name, 10000000],
    },
  });

  const senderAuthenticator = aptos.transaction.sign({
    signer: account,
    transaction,
  });

  const submittedTransaction = await aptos.transaction.submit.simple({
    transaction,
    senderAuthenticator,
  });

  return `${submittedTransaction.hash}`
}