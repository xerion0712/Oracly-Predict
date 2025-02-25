import type { Handler } from 'aws-lambda';
import type { EventBridgeHandler } from "aws-lambda";



export const handler: EventBridgeHandler<"Scheduled Event", null, void> = async (event) => {
  console.log("event", JSON.stringify(event, null, 2))
}