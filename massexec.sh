# Task 6

usage() {
    printf 'Использование: %s [--path каталог] [--mask шаблон] [--number число] команда\n' "$0" >&2
}

dirpath='.'
mask='*'
number=''

while (($# > 0)); do
    case $1 in
        --path|--mask|--number)
            option=$1

            if (($# < 2)); then
                printf 'Ошибка: у %s отсутствует значение.\n' "$option" >&2
                exit 1
            fi

            case $option in
                --path) dirpath=$2 ;;
                --mask) mask=$2 ;;
                --number) number=$2 ;;
            esac

            shift 2
            ;;
        --)
            shift
            break
            ;;
        --help)
            usage
            exit 0
            ;;
        -*)
            printf 'Неизвестная опция: %s\n' "$1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if (($# != 1)); then
    usage
    exit 1
fi

if [[ ! -d $dirpath ]]; then
    printf 'Ошибка: каталог не существует: %s\n' "$dirpath" >&2
    exit 1
fi

if [[ -z $mask ]]; then
    printf 'Ошибка: пустая маска.\n' >&2
    exit 1
fi

if [[ -z $number ]]; then
    if command -v nproc >/dev/null 2>&1; then
        number=$(nproc)
    elif [[ $(uname -s) == Darwin ]]; then
        number=$(sysctl -n hw.logicalcpu)
    else
        number=$(getconf _NPROCESSORS_ONLN 2>/dev/null) || number=1
    fi
fi

if [[ ! $number =~ ^[1-9][0-9]*$ ]]; then
    printf 'Ошибка: --number должно быть целым числом больше нуля.\n' >&2
    exit 1
fi

processor=$1

if [[ $processor != */* ]]; then
    processor=$(type -P "$processor") || processor=''
fi

if [[ ! -f $processor || ! -x $processor ]]; then
    printf 'Ошибка: команда не найдена или не исполняется: %s\n' "$1" >&2
    exit 1
fi

absdir=$(cd "$dirpath" 2>/dev/null && pwd -P) || exit 1

shopt -s nullglob dotglob

files=()

for file in "$absdir"/*; do
    [[ -f $file && ! -L $file ]] || continue

    [[ ${file##*/} == $mask ]] || continue

    files+=("$file")
done

total=${#files[@]}

if ((total == 0)); then
    printf 'Нет файлов, подходящих под маску %s.\n' "$mask"
    exit 0
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/massexec.XXXXXX") || exit 1

trap 'rm -rf "$tmp_dir"' EXIT

mkfifo "$tmp_dir/done" || exit 1

exec 3<> "$tmp_dir/done" || exit 1

pids=()

start_job() {
    local index=$1

    (
        "$processor" "${files[index]}"

        result=$?

        printf '%s %s\n' "$index" "$result" >&3
    ) &

    pids[index]=$!

    printf 'Запущено: %s (PID %s)\n' \
        "${files[index]}" "${pids[index]}"
}

printf 'Файлов: %d. Максимум процессов: %s.\n' "$total" "$number"

next=0
finished=0
failed=0

while ((next < total && next < number)); do
    start_job "$next"
    ((next += 1))
done

while ((finished < total)); do

    IFS=' ' read -r job_id code <&3 || continue

    wait "${pids[job_id]}"

    if ((code != 0)); then
        ((failed += 1))

        printf 'Ошибка обработки: %s (код %d)\n' \
            "${files[job_id]}" "$code" >&2
    fi

    ((finished += 1))

    if ((next < total)); then
        start_job "$next"
        ((next += 1))
    fi
done

exec 3>&-

printf 'Готово. Обработано: %d, с ошибками: %d.\n' \
    "$finished" "$failed"

((failed == 0))