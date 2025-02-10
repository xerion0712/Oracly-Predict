import { generateClient } from "aws-amplify/api";
import { Schema } from "@/amplify/data/resource";
import { createAIHooks } from "@aws-amplify/ui-react-ai";


const client = generateClient<Schema>({ authMode: "apiKey" });
const { useAIConversation, useAIGeneration } = createAIHooks(client);


const useAI = () => {


    

    return {

    }
}

export default useAI