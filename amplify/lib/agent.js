// import axios from "axios";

// const ATOMA_API_KEY = process.env.ATOMA_API_KEY || ""

class Agent {

    // messages

    constructor() {

    }

    getSystemPrompt = (roundNumber, source, context, period) => {
        return {
            role: "system",
            content: [
                `You are an AI assistant for the Legato DeFi prediction market. Your role is to help users place bets, propose new outcomes, and provide guidance throughout the prediction round.\n`,
                `Round Details:\n`,
                `Round Number: ${roundNumber}\n`,
                `Source: ${source} – The latest data has been fetched and provided as follows:\n`,
                `${context}\n`,
                `Outcomes Available:\n`,
                `None\n`,
                `Predicting Period: ${period} \n`, 
                `Core Tasks:\n`,
                `1. **Monitor Market Trends** – Analyze real-time data from the source.\n`,
                `2. **Propose Outcomes** – Suggest potential outcomes for this round based on market trends.\n`,
                `3. **Assign Weights** – Calculate probabilities for each proposed outcome\n. `,
                `4. **Guide Users** – Answer questions, assist with betting, and clarify rules.\n`,
                `Rules:\n`,
                `- When the user greets with "hello" or asks "what can you do?", provide round information and convince them to place a bet.\n`,
                `- If no outcomes are available, suggest that they propose a new one and offer assistance.\n`,
                `- When adding a new outcome, ask for confirmation before proceeding and inform the user that a modal will open for input.\n`,
                `- Be diverse about new outcomes, it can be such as token price, ranking, or trading volume.\n`,
                `- Outcomes must be within the current round’s predicting period.\n`,
                `- Users can only place bets before the round starts. Once started, outcomes and weights are finalized.\n`,
                `- When users want to bet, show them the available outcomes or the available outcomes tab above.\n`,
                `- All bets contribute to the prize pool. Prizes are distributed among winning outcomes based on assigned weights, with unclaimed amounts rolling over to the next round.\n`
            ].join("")
        }
    }

    getOutcomePrompt = (outcomes) => {

        const context = outcomes.length === 0 ? "None" : outcomes.map((outcome) => {
            return `**${outcome.title}**\nOutcome ID: ${outcome.onchainId}\nResolution Date: ${ (new Date( Number(outcome.resolutionDate) * 1000 )).toDateString() }\n`
        }).join("\n\n")

        return {
            role: "system",
            content: [
                `Outcomes Available:\n`,
                context,
            ].join("")
        }
    }

    // query = async (query) => {

    //     this.messages.push({
    //         role: "user",
    //         content: query
    //     })

    //     const response = await axios.post(
    //         'https://api.atoma.network/v1/chat/completions',
    //         {
    //             stream: false,
    //             model: 'deepseek-ai/DeepSeek-R1',
    //             messages: this.messages,
    //             max_tokens: 2048
    //         },
    //         this.getHeader()
    //     )

    //     let result = response.data.choices[0].message.content
    
    //     if (result.indexOf("</think>") !== -1) {
    //         result = result.split("</think>")[1]
    //     }

    //     this.messages.push({
    //         role: "assistant",
    //         content: result
    //     })

    //     return result
    // }

    // getHeader = () => {
    //     return {
    //         headers: {
    //             "Content-Type": "application/json",
    //             "Authorization": `Bearer ${ATOMA_API_KEY}`
    //         }
    //     }
    // }



}

export default Agent