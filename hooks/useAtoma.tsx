import axios from "axios";

const ATOMA_API_KEY = process.env.ATOMA_API_KEY || ""

const useAtoma = () => {

    const getHeader = () => (
        {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${ATOMA_API_KEY}`
            }
        }
    )

    const query = async (messages: any) => {

        const response = await axios.post(
            'https://api.atoma.network/v1/chat/completions',
            {
                stream: false,
                model: 'deepseek-ai/DeepSeek-R1',
                messages,
                max_tokens: 1024
            },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${ATOMA_API_KEY}`
                }
            }
        )

        let result = response.data.choices[0].message.content

        const lastThinkIndex = result.lastIndexOf("</think>");

        if (lastThinkIndex !== -1) {
            result = result.slice(lastThinkIndex + 8).trim(); // Content after the last colon
        }

        return result

    }


    // From below are unused

    const generateOutcome = async ({ context, topic, asset }: any) => {

        let messages = [
            {
                role: "system",
                content: `You are an AI assistant that helps users propose new prediction outcomes for DeFi prediction market project based on real-time data likes Will BTC hits 100,000$ by Friday?`
            },
            {
                role: 'user',
                content: [
                    `Suggest a possible prediction outcome on the topic ${topic} from the provided content.\n`,
                    asset ? "And around asset " + asset : "",
                    `With the resolution date set within the week if today is ${(new Date()).toDateString()}\n`,
                    "Provided content:",
                    context
                ].join("")
            }
        ]

        console.log("messages : ", messages)

        let response = await axios.post(
            'https://api.atoma.network/v1/chat/completions',
            {
                stream: false,
                model: 'deepseek-ai/DeepSeek-R1',
                messages,
                max_tokens: 2048
            },
            getHeader()
        )

        let content = response.data.choices[0].message.content
        content = content.split("</think>")[1]

        console.log("final content : ", content)

        const regex = /\*\*.*?\*\*\s*([\s\S]*?)(?=\n\*\*|$)/;

        const match = content.match(regex);
        if (match) {
            return (match[1].trim()).replaceAll("*", "")
        } else {
            return undefined
        }

    }

    const fetchTeams = async ({ context, hackathon }: any) => {

        let messages = [
            {
                role: "system",
                content: `You are an AI assistant that reads official website content to fetch teams. `
            },
            {
                role: 'user',
                content: [
                    "List all teams from the provided markdown content.",
                    "Provided content:",
                    context
                ].join("")
            }
        ]

        let response = await axios.post(
            'https://api.atoma.network/v1/chat/completions',
            {
                stream: false,
                model: 'deepseek-ai/DeepSeek-R1',
                messages,
                max_tokens: 1024
            },
            getHeader()
        )

        console.log(response.data)

        let listTeamResult = response.data.choices[0].message.content
        listTeamResult = listTeamResult.split("</think>")[1]

        // Regex to match team names with **TEAM**
        const regex = /\d+\.\s\*\*(.*?)\*\*/g;
        let teams = [];
        let match;

        while ((match = regex.exec(listTeamResult)) !== null) {
            teams.push(match[1]);
        }

        if (teams.length === 0) {
            // Regex to match team names after numbered list
            const teamRegex = /^\d+\.\s+(.*)$/gm;

            // Extract team names
            teams = [...listTeamResult.matchAll(teamRegex)].map(match => match[1]);
        }

        if (teams.length === 0) {
            throw new Error("No teams found. The website may be down or there may be another issue.")
        }

        console.log("Teams: ", teams)

        messages.push({
            role: "assistant",
            content: listTeamResult
        })


        // Only 1 team at a time for the hackathon to save token cost
        const team = teams[Math.floor(Math.random() * teams.length)];

        console.log("Fetching description from Team: ", team)

        messages.push({
            role: 'user',
            content: `Fetch description of team ${team}`
        })

        response = await axios.post(
            'https://api.atoma.network/v1/chat/completions',
            {
                stream: false,
                model: 'deepseek-ai/DeepSeek-R1',
                messages,
                max_tokens: 1024
            },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${ATOMA_API_KEY}`
                }
            }
        )

        let description = response.data.choices[0].message.content

        const lastThinkIndex = description.lastIndexOf("</think>");

        // If a colon is found, split the string at the last colon
        if (lastThinkIndex !== -1) {
            description = description.slice(lastThinkIndex + 8).trim(); // Content after the last colon
        }

        if (description.indexOf(">") !== -1) {
            description = description.split(">")[1]
        }

        if (description.indexOf("the provided content:") !== -1) {
            description = description.split("the provided content:")[1]
        }

        if (description.indexOf("---") !== -1) {
            description = description.split("---")[1]
        }

        console.log("Description after trimmed: ", description)

        const { data } = await hackathon.teams()

        const maxTeamId = data.reduce((result: number, item: any) => {
            if (item.onchainId > result) {
                result = item.onchainId
            }
            return result
        }, 0)

        const teamId = maxTeamId + 1
        const hackathonId = hackathon.id

        return {
            hackathonId,
            teamId,
            team,
            description
        }
    }

    const reviewTeam = async ({ hackathon, prizes, teams, selected }: any) => {

        const systemPrompt = [
            "You are an AI assistant for reviewing teams participating in the hackathon ",
            "with the following details:\n\n",
            `Hackathon Name : ${hackathon.title}\n`,
            `Hackathon Prizes:\n`,
        ].concat(prizes.map((item: any) => `- ${item.title}\n`)).join("")

        const initPrompt = [
            "Given the following teams:\n\n"
        ].concat(teams.map((item: any, index: number) => `${index + 1}. **${item.name}** - ${item.description}\n`))
            .concat([
                `\n\nPlease help review Team ${selected} based on the following factors:\n`,
                "Innovation: Does the project introduce a novel concept or improve existing ideas?\n",
                "Impact & Feasibility: Can this project have real-world applications? Is it viable beyond the hackathon?",
                "Prize Tier Relevance: Does this project align with the criteria of specific prize categories?"
            ])
            .join("")

        let messages = [
            {
                role: "system",
                content: systemPrompt
            },
            {
                role: 'user',
                content: initPrompt
            }
        ]

        let response = await axios.post(
            'https://api.atoma.network/v1/chat/completions',
            {
                stream: false,
                model: 'deepseek-ai/DeepSeek-R1',
                messages,
                max_tokens: 2048
            },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${ATOMA_API_KEY}`
                }
            }
        );

        console.log(response.data)

        let reviewMessage = response.data.choices[0].message.content
        reviewMessage = reviewMessage.split("</think>")[1]

        console.log("reviewMessage:", reviewMessage)

        messages.push({
            role: "assistant",
            content: reviewMessage
        })

        messages.push({
            role: 'user',
            content: `Now assign a rating (0-100%) on Team ${selected}`
        })

        response = await axios.post(
            'https://api.atoma.network/v1/chat/completions',
            {
                stream: false,
                model: 'deepseek-ai/DeepSeek-R1',
                messages,
                max_tokens: 1024
            },
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${ATOMA_API_KEY}`
                }
            }
        )

        let comment = response.data.choices[0].message.content

        comment = comment.split("</think>")[1]

        console.log("final comment: ", comment)

        return comment
    }

    return {
        fetchTeams,
        reviewTeam,
        generateOutcome,
        query
    }

}

export default useAtoma