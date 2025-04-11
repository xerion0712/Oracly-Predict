

import { defineFunction } from '@aws-amplify/backend';
import { secret } from '@aws-amplify/backend';

export const chat2 = defineFunction({
  name: 'chat2',
  entry: './handler.ts',
  environment: {
    ANTHROPIC_API_KEY: secret('ANTHROPIC_API_KEY'),
    APTOS_TEST_KEY: secret('APTOS_TEST_KEY')
  },
  timeoutSeconds: 600
});