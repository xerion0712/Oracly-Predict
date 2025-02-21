
export const shortAddress = (address: string, first = 6, last = -4) => {
    if (!address) return ''
    return `${address.slice(0, first)}...${address.slice(last)}`
}

export const parseSuiAmount = (input: any, decimals: number) => {
    return (Number(input) / 10 ** decimals)
}

export const parseAmount = (input: any) => {
    input = Number(input)

    if (input % 1 === 0) {

    } else if (input >= 1000000) {
        input = `${(input / 1000000).toFixed(4)}M`
    }
    else if (input >= 10000) {
        input = `${(input).toFixed(3)}`
    }
    else if (input >= 1000) {
        input = `${input.toFixed(2)}`
    }
    else if (input >= 10) {
        input = `${input.toFixed(4)}`
    } else {
        input = `${input.toFixed(4)}`
    }

    return input
}


export const secondsToHHMMSS = (totalSeconds: number) => {
    var hours = Math.floor(totalSeconds / 3600);
    var minutes = Math.floor((totalSeconds - (hours * 3600)) / 60);
    var seconds = totalSeconds - (hours * 3600) - (minutes * 60);

    let strHours: string = `${hours}`
    let strMinutes: string = `${minutes}`
    let strSeconds: string = `${seconds}`

    // Padding the values to ensure they are two digits
    if (hours < 10) { strHours = "0" + hours; }
    if (minutes < 10) { strMinutes = "0" + minutes; }
    if (seconds < 10) { strSeconds = "0" + seconds; }

    return {
        hours: strHours,
        minutes: strMinutes,
        seconds: strSeconds
    }
}

export const secondsToDDHHMMSS = (totalSeconds: number) => {

    var days = Math.floor(totalSeconds / 24 / 60 / 60);
    var hoursLeft = Math.floor((totalSeconds) - (days * 86400));
    var hours = Math.floor(hoursLeft / 3600);
    var minutesLeft = Math.floor((hoursLeft) - (hours * 3600));
    var minutes = Math.floor(minutesLeft / 60);
    var seconds = totalSeconds % 60;

    let strDays: string = `${days}`
    let strHours: string = `${hours}`
    let strMinutes: string = `${minutes}`
    let strSeconds: string = `${seconds}`

    // Padding the values to ensure they are two digits
    if (hours < 10) { strHours = "0" + hours; }
    if (minutes < 10) { strMinutes = "0" + minutes; }
    if (seconds < 10) { strSeconds = "0" + seconds; }

    return {
        days: strDays,
        hours: strHours,
        minutes: strMinutes,
        seconds: strSeconds
    }
}

export const shorterText = (name: string, limit = 40) => {
    return name.length > limit ? `${name.slice(0, limit)}...` : name
}

export const slugify = (text: string) => {
    return text
        .toString()
        .normalize('NFD')                   // split an accented letter in the base letter and the acent
        .replace(/[\u0300-\u036f]/g, '')   // remove all previously split accents
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '-')
        .replace(/[^\w\-]+/g, '')
        .replace(/\-\-+/g, '-');
}

export const comparePercentageChange = (arr: any[]) => {

    if (!arr) {
        return 0
    }

    if (arr.length < 2) {
        return 0
    }

    const firstElement = Number(arr[0]);
    const lastElement = Number(arr[arr.length - 1]);

    const percentageChange = ((lastElement - firstElement) / firstElement) * 100;

    return percentageChange.toFixed(2);
}

export const pastWeekDates = () => {

    let output = []

    let today = new Date();

    for (let i = 0; i < 6; i++) {
        const string = `${today.getDate()}/${today.getMonth() + 1}`
        output.push(string)
        today.setDate(today.getDate() - 1)
    }

    return output.reverse()

}

export const vaultTypeToTokenName = (vaultType: string) => {

    let tokenName = ""

    if (vaultType.includes("vault_template::")) {
        tokenName = `PT-${vaultType.split("vault_template::")[1].toUpperCase()}`
    }

    if (vaultType.includes("vault::VAULT")) {
        tokenName = "YT"
    }

    return slugify(tokenName)
}

export const parseCoinType = (input: string | undefined) => {
    if (input === undefined) {
        return
    }

    input = input.replaceAll("0x", "")

    if (input === "2::sui::SUI") {
        input = "0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
    }

    return input
}

 

export const parseTables = (input: string) => {
    const tableRegex = /\|.*\|\n(\|[-| ]+\|\n)?([\s\S]*?)\|.*\|/g;
    const tables = input.match(tableRegex);
    return tables ? cleanUrls(tables.join("\n")) : undefined
}

export const cleanUrls = (input: string) => {
    const cleanTable = (input.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1')).replace(/!\[.*?<br><br>(.*?)<br><br>.*?\]\(.*?\)/g, '$1');
    return cleanTable
}