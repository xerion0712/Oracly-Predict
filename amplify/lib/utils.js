
export const parseTables = (input) => {
    const tableRegex = /\|.*\|\n(\|[-| ]+\|\n)?([\s\S]*?)\|.*\|/g;
    const tables = input.match(tableRegex);
    return tables ? cleanUrls(tables.join("\n")) : undefined
}

export const cleanUrls = (input) => {
    const cleanTable = (input.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1')).replace(/!\[.*?<br><br>(.*?)<br><br>.*?\]\(.*?\)/g, '$1');
    return cleanTable
}