import { defineBackend } from '@aws-amplify/backend';
import { auth } from './auth/resource';
import { data } from './data/resource';
import { faucet } from './functions/faucet/resource';

defineBackend({
  auth,
  data,
  faucet
});
