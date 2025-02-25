import { defineFunction } from "@aws-amplify/backend";


export const scheduler = defineFunction({
    name: "scheduler",
    schedule: "every 10m",
    entry: './handler.ts'
})