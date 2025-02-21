
import OpenAI from "openai";

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
        }];

        const completion = await openai.chat.completions.create({
            model: "gpt-4o",
            messages,
            tools,
            store: false,
        })

        return completion.choices[0].message

    }

    return {
        query
    }
}

export default useOpenAI