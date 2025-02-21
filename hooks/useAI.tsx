 
import type { Schema } from "../amplify/data/resource"
import { generateClient } from "aws-amplify/api"

const client = generateClient<Schema>()



const useAI = () => {


    const query = async (messages: any) => {

        const tools: any = [{
            "type": "function",
            "function": {
                "name": "create_outcome",
                "description": "Create a new outcome with a title and the resolution date.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "title": {
                            "type": "string",
                            "description": "Outcome title."
                        },
                        "resolutionDate": {
                            "type": "string",
                            "description": "Outcome resolution date."
                        }
                    },
                    "required": [
                        "title",
                        "resolutionDate"
                    ],
                    "additionalProperties": false
                },
                "strict": true
            }
        },
        {
            "type": "function",
            "function": {
                "name": "place_bet",
                "description": "Place a bet with the round ID and outcome ID.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "roundId": {
                            "type": "number",
                            "description": "Round ID."
                        },
                        "outcomeId": {
                            "type": "number",
                            "description": "Outcome ID."
                        }
                    },
                    "required": [
                        "roundId",
                        "outcomeId"
                    ],
                    "additionalProperties": false
                },
                "strict": true
            }
        }
        ];

        const result: any = await client.queries.Chat({
            messages: JSON.stringify(messages),
            tools: JSON.stringify(tools)
        })
 
        return JSON.parse(result.data)
    }

    return {
        query
    }
}

export default useAI