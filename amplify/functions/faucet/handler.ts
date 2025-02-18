import type { Handler } from 'aws-lambda';
import type { Schema } from "../../data/resource"

export const handler: Schema["Faucet"]["functionHandler"] = async (event) => {
    // arguments typed from `.arguments()`
    const { name } = event.arguments
    // return typed from `.returns()`
    return `Hello, ${name}!`
  }