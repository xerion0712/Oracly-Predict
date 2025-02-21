import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"

import OpenAI from "openai";

export const handler: Schema["Chat"]["functionHandler"] = async (event) => {
 
  const messages: any = event.arguments.messages

  console.log("incoming messages: ", messages)

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

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
  }];

  const completion = await openai.chat.completions.create({
    model: "gpt-4o",
    messages,
    tools,
    store: false,
  })

  return completion.choices[0].message


}