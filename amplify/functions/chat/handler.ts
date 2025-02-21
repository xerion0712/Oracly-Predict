import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"

import OpenAI from "openai";

export const handler: Schema["Chat"]["functionHandler"] = async (event) => {
 
  const messages: any = event.arguments.messages
  const tools: any = event.arguments.tools

  console.log("incoming messages: ", messages)
  console.log("incoming tools: ", tools)

  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
 
  const completion = await openai.chat.completions.create({
    model: "gpt-4o",
    messages,
    tools,
    store: false,
  })

  return completion.choices[0].message


}