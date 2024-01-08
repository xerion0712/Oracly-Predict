
export const shortAddress = (address, first = 6, last = -4) => {
    return `${address.slice(0, first)}...${address.slice(last)}`
}

export const slugify = (text) => {
    return text
        .toString()
        .normalize('NFD')                   // split an accented letter in the base letter and the acent
        .replace(/[\u0300-\u036f]/g, '')   // remove all previously split accents
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '-')
        .replace(/[^\w\-]+/g, '')
        .replace(/\-\-+/g, '-');
};

export const shorterText = (name, limit = 40) => {
    return name.length > limit ? `${name.slice(0, limit)}...` : name
}

export const secondsToHHMMSS = (totalSeconds) => {
    var hours = Math.floor(totalSeconds / 3600);
    var minutes = Math.floor((totalSeconds - (hours * 3600)) / 60);
    var seconds = totalSeconds - (hours * 3600) - (minutes * 60);

    // Padding the values to ensure they are two digits
    if (hours < 10) { hours = "0" + hours; }
    if (minutes < 10) { minutes = "0" + minutes; }
    if (seconds < 10) { seconds = "0" + seconds; }

    return {
        hours,
        minutes,
        seconds
    }
}

export const secondsToDDHHMMSS = (totalSeconds) => {

    var days = Math.floor(totalSeconds / 24 / 60 / 60);
    var hoursLeft = Math.floor((totalSeconds) - (days * 86400));
    var hours = Math.floor(hoursLeft / 3600);
    var minutesLeft = Math.floor((hoursLeft) - (hours * 3600));
    var minutes = Math.floor(minutesLeft / 60);
    var seconds = totalSeconds % 60;

    // Padding the values to ensure they are two digits
    if (hours < 10) { hours = "0" + hours; }
    if (minutes < 10) { minutes = "0" + minutes; }
    if (seconds < 10) { seconds = "0" + seconds; }

    return {
        days,
        hours,
        minutes,
        seconds
    }
}

export const parseAmount = (input) => {
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