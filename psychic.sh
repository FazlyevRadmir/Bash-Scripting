# Task 1

RED=$'\033[31m'
GREEN=$'\033[32m'
RESET=$'\033[0m'

step=1
hits=0
misses=0
history=()

while true; do
    secret=$((RANDOM % 10))
    printf 'Step: %d\n' "$step"

    while true; do
        if ! read -r -p 'Please enter number from 0 to 9 (q - quit): ' guess; then
            printf '\nInput ended. Game over!\n'
            exit 0
        fi

        case "$guess" in
            q)
                printf 'Game over!\n'
                exit 0
                ;;
            [0-9])
                break
                ;;
            *)
                printf 'Invalid input! Enter one digit from 0 to 9, or q to quit.\n'
                ;;
        esac
    done

    if [[ "$guess" == "$secret" ]]; then
        ((hits += 1))
        history+=("${GREEN}${secret}${RESET}")
        printf 'Hit! My number: %d\n' "$secret"
    else
        ((misses += 1))
        history+=("${RED}${secret}${RESET}")
        printf 'Miss! My number: %d\n' "$secret"
    fi

    total=$((hits + misses))
    hit_percent=$(((hits * 100 + total / 2) / total))
    miss_percent=$((100 - hit_percent))
    printf 'Hit: %d%% Miss: %d%%\n' "$hit_percent" "$miss_percent"

    length=${#history[@]}
    start=$((length > 10 ? length - 10 : 0))
    printf 'Numbers: '
    for ((i = start; i < length; i++)); do
        if ((i > start)); then
            printf ' '
        fi
        printf '%s' "${history[i]}"
    done
    printf '\n\n'

    ((step += 1))
done