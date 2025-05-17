package main

# Do Not store secrets in ENV variables
secrets_env = {
    "passwd",
    "password",
    "pass",
    "secret",
    "key",
    "access",
    "api_key",
    "apikey",
    "token",
    "tkn",
}

deny[msg] {    
    input[i].Cmd == "env"
    val := input[i].Value
    some j
    some k
    contains(lower(val[j]), secrets_env[k])
    msg = sprintf("Line %d: Potential secret in ENV key found: %s", [i, val[j]])
}

# Do not use 'latest' tag for base image
deny[msg] {
    input[i].Cmd == "from"
    val := split(input[i].Value, ":")
    count(val) > 1
    lower(val[1]) == "latest"
    msg = sprintf("Line %d: do not use 'latest' tag for base images", [i])
}

# Avoid curl bashing
deny[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    matches := regex.find_n(`(curl
|wget)[^|^>]*[|>]`, lower(val), -1)
    count(matches) > 0
    msg = sprintf("Line %d: Avoid curl bashing", [i])
}

# Do not upgrade your system packages
warn[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    regex.match(`.*?(apk|yum|dnf|apt|pip).+?(install|dist-upgrade|check-upgrade|group-upgrade|update|upgrade).*`, lower(val))
    msg = sprintf("Line %d: Do not upgrade your system packages: %s", [i, val])
}

# Do not use ADD if possible
deny[msg] {
    input[i].Cmd == "add"
    msg = sprintf("Line %d: Use COPY instead of ADD", [i])
}

# Any user...
any_user {
    input[i].Cmd == "user"
}

deny[msg] {
    not any_user
    msg = "Do not run as root, use USER instead"
}

# ... but do not root
forbidden_users = {
    "root",
    "toor",
    "0",
}

deny[msg] {
    command := "user"
    users := [name |

 input[i].Cmd == "user"; name := input[i].Value]
    lastuser := users[count(users)-1]
    some k
    forbidden_users[k] == lower(lastuser)
    msg = sprintf("Line %d: Last USER directive (USER %s) is forbidden", [i, lastuser])
}

# Do not sudo
deny[msg] {
    input[i].Cmd == "run"
    val := concat(" ", input[i].Value)
    contains(lower(val), "sudo")
    msg = sprintf("Line %d: Do not use 'sudo' command", [i])
}

# Use multi-stage builds
default multi_stage = false

multi_stage {
    some i
    input[i].Cmd == "copy"
    val := concat(" ", input[i].Flags)
    contains(lower(val), "--from=")
}

deny[msg] {
    not multi_stage
    msg = sprintf("You COPY, but do not appear to use multi-stage builds...", [])
}