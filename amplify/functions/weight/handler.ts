import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"

import OpenAI from "openai";
import { z } from "zod";
import { zodResponseFormat } from "openai/helpers/zod";
import { env } from '$amplify/env/weight';

const OutcomeWeight = z.object({
  outcomeId: z.number(),
  outcomeWeight: z.number(),
});

const OutcomeWeights = z.object({
  outcomes: z.array(OutcomeWeight)
});

export const handler: Schema["WeightAssignment"]["functionHandler"] = async (event) => {

  const messages: any = event.arguments.messages

  const openai = new OpenAI({ apiKey: env.OPENAI_API_KEY });

  const completion = await openai.beta.chat.completions.parse({
    model: "gpt-4o",
    messages: messages,
    response_format: zodResponseFormat(OutcomeWeights, "outcome_weights"),
  });

  const output = completion.choices[0].message.parsed;

  return (output && output?.outcomes) ? output.outcomes : []
}