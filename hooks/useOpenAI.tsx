
import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";

const OutcomeWeight = z.object({
    outcomeId: z.number(),
    outcomeWeight: z.number(),
});

const OutcomeWeights = z.object({
    outcomes: z.array(OutcomeWeight)
});

// This uses for local testing only

const useOpenAI = () => {


    const query = async (messages: any) => {

        const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY, dangerouslyAllowBrowser: true });

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

        const completion = await openai.chat.completions.create({
            model: "gpt-4o",
            messages,
            tools,
            store: false,
        })

        return completion.choices[0].message

    }

    const parse = async (messages: any) => {

        const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY, dangerouslyAllowBrowser: true });

        const completion = await openai.beta.chat.completions.parse({
            model: "gpt-4o",
            messages: messages,
            response_format: zodResponseFormat(OutcomeWeights, "outcome_weights"),
        });

        const event = completion.choices[0].message.parsed;

        return (event && event?.outcomes) ? event.outcomes : []
    }

    return {
        query,
        parse
    }
}

export default useOpenAI