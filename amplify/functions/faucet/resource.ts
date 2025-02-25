

import { defineFunction } from '@aws-amplify/backend';
import { secret } from '@aws-amplify/backend';

export const faucet = defineFunction({
  // optionally specify a name for the Function (defaults to directory name)
  name: 'faucet',
  // optionally specify a path to your handler (defaults to "./handler.ts")
  entry: './handler.ts',
  environment: {
    APTOS_MANAGED_KEY: secret('APTOS_MANAGED_KEY')
  },
  timeoutSeconds: 10
});