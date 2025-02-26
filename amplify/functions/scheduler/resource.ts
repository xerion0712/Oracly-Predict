import { defineFunction } from "@aws-amplify/backend";
import { secret } from '@aws-amplify/backend';

export const scheduler = defineFunction({
    name: "scheduler",
    schedule: "every 10m",
    resourceGroupName: "data",
    entry: './handler.ts',
    environment: {
        APTOS_MANAGED_KEY: secret('APTOS_MANAGED_KEY'),
        FIRECRAWL_API_KEY: secret('FIRECRAWL_API_KEY')
    },
    timeoutSeconds: 200
})