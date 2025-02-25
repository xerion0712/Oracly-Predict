import type { Handler } from 'aws-lambda';
import type { EventBridgeHandler } from "aws-lambda"; 
import type { Schema } from '../../data/resource';
import { Amplify } from 'aws-amplify';
import { generateClient } from 'aws-amplify/data';
import { getAmplifyDataClientConfig } from '@aws-amplify/backend/function/runtime';
import { env } from '$amplify/env/scheduler';

const { resourceConfig, libraryOptions } = await getAmplifyDataClientConfig(env);

Amplify.configure(resourceConfig, libraryOptions);

const client = generateClient<Schema>();


export const handler: EventBridgeHandler<"Scheduled Event", null, void> = async (event) => {
  console.log("event", JSON.stringify(event, null, 2))



}