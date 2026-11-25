# Read a friendly duration on stdin and print its length in whole seconds.
{ input = input " " $0 }
END {
    rest = tolower(input)
    total = 0
    parts = 0
    while (1) {
        sub(/^[[:space:]]+/, "", rest)
        if (rest == "") break
        if (!match(rest, /^([0-9]+([.][0-9]+)?|[.][0-9]+)/)) exit 1
        value = substr(rest, 1, RLENGTH) + 0
        rest = substr(rest, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", rest)
        if (match(rest, /^(hours?|hrs?|h)/)) {
            total += value * 3600
            rest = substr(rest, RLENGTH + 1)
        } else if (match(rest, /^(minutes?|mins?|m)/)) {
            total += value * 60
            rest = substr(rest, RLENGTH + 1)
        } else if (rest == "" && parts == 0) {
            total += value * 60
        } else {
            exit 1
        }
        parts++
    }
    if (parts == 0 || total < 60 || total > 604800) exit 1
    printf "%.0f\n", total
}
