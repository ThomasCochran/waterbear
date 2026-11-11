# lib/menu.sh — Waterbear's own arrow-key menu (pure bash, works in a TTY too).
#
#   ↑ ↓  (j k, PgUp PgDn, Home End)   move
#   →  Enter  l                       open / select (in a checklist: done)
#   ←  Esc  h  q                      back (in a checklist: cancel)
#   Space  x  Tab                     tick / untick (checklists)
#
# Items are passed in the arrays _M_LABELS and _M_VALUES. A label starting with "--" is a
# section heading: shown, but the cursor skips it. Drawing goes to /dev/tty, so the caller
# can capture the result from stdout.

_m_rgb() {  # _m_rgb RRGGBB -> "r;g;b"
    local h="${1:-ffffff}"
    [[ "$h" =~ ^[0-9a-fA-F]{6}$ ]] || h=ffffff
    printf '%d;%d;%d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

_m_key() {  # reads one key from the terminal, prints a name: up down left right enter space home end pgup pgdn esc or the character
    local k rest
    IFS= read -rsn1 k < /dev/tty || { echo esc; return; }
    case "$k" in
        $'\e')
            IFS= read -rsn1 -t 0.02 rest < /dev/tty || { echo esc; return; }
            if [[ "$rest" == "[" || "$rest" == "O" ]]; then
                IFS= read -rsn1 -t 0.02 k < /dev/tty || { echo esc; return; }
                case "$k" in
                    A) echo up ;; B) echo down ;; C) echo right ;; D) echo left ;;
                    H) echo home ;; F) echo end ;;
                    [0-9]) local t; IFS= read -rsn1 -t 0.02 t < /dev/tty
                           case "$k" in 5) echo pgup ;; 6) echo pgdn ;; 1|7) echo home ;; 4|8) echo end ;; *) echo none ;; esac ;;
                    *) echo none ;;
                esac
            else
                echo esc
            fi ;;
        "")     echo enter ;;
        " ")    echo space ;;
        $'\t')  echo space ;;
        *)      printf '%s\n' "$k" ;;
    esac
}

# _menu MODE HEADER CURSOR_INDEX — MODE is pick or checks. For checks, _M_ON[i]=1 marks ticked items.
# Sets _M_RESULT (pick: the chosen index; checks: space-separated ticked indexes). Returns 1 on back.
_menu() {
    local mode="$1" header="$2" cur="${3:-0}" n=${#_M_LABELS[@]}
    local cols rows vis top=0 drawn=0 i key line
    local ca cb cf cd
    ca="$(_m_rgb "${P_A:-5fd7ff}")"; cb="$(_m_rgb "${P_B:-ffffff}")"
    cf="$(_m_rgb "${P_FG:-dddddd}")"; cd="$(_m_rgb "${P_DIM:-888888}")"
    local C_A=$'\e[38;2;'"$ca"'m' C_B=$'\e[1;38;2;'"$cb"'m' C_F=$'\e[38;2;'"$cf"'m' C_D=$'\e[38;2;'"$cd"'m'
    local C_H=$'\e[1;38;2;'"$ca"'m' R=$'\e[0m'
    local hint
    if [[ "$mode" == checks ]]; then hint="↑↓ move · space/x tick · → or enter done · ← back"
    else hint="↑↓ move · → or enter open · ← back"; fi

    # first selectable item at or after the cursor
    _m_ok() { [[ "${_M_LABELS[$1]}" != --* ]]; }
    if (( n == 0 )); then return 1; fi
    (( cur < 0 || cur >= n )) && cur=0
    while (( cur < n )) && ! _m_ok "$cur"; do ((cur++)); done
    (( cur >= n )) && cur=0

    printf '\e[?25l' > /dev/tty   # hide the cursor
    while true; do
        cols=$(tput cols 2> /dev/null || echo 80); rows=$(tput lines 2> /dev/null || echo 24)
        vis=$(( rows - ${UI_RESERVED:-9} )); (( vis < 4 )) && vis=4; (( vis > n )) && vis=$n
        (( cur < top )) && top=$cur
        (( cur >= top + vis )) && top=$(( cur - vis + 1 ))
        # keep a heading visible above the first item of a section
        (( top > 0 && top == cur )) && [[ "${_M_LABELS[$((top - 1))]}" == --* ]] && top=$((top - 1))

        local out="" w=$(( cols - 6 )) lbl mark
        (( drawn > 0 )) && out+=$'\e['"$drawn"'A'
        out+=$'\r\e[J'
        out+=" ${C_H}${header:0:$((cols - 2))}${R}"$'\n'
        drawn=1
        for (( i = top; i < top + vis && i < n; i++ )); do
            lbl="${_M_LABELS[$i]}"
            if [[ "$lbl" == --* ]]; then
                lbl="${lbl#--}"; lbl="${lbl# }"
                out+="  ${C_D}── ${lbl:0:$((w - 4))}${R}"$'\n'
            else
                mark=""
                if [[ "$mode" == checks ]]; then
                    if [[ "${_M_ON[$i]:-}" == 1 ]]; then mark="[x] "; else mark="[ ] "; fi
                fi
                lbl="${mark}${lbl}"; lbl="${lbl:0:$w}"
                if (( i == cur )); then out+=" ${C_B}❯ ${lbl}${R}"$'\n'
                elif [[ "$mode" == checks && "${_M_ON[$i]:-}" == 1 ]]; then out+="   ${C_A}${lbl}${R}"$'\n'
                else out+="   ${C_F}${lbl}${R}"$'\n'; fi
            fi
            ((drawn++))
        done
        line="$hint"
        (( n > vis )) && line+="  ·  $((cur + 1))/$n"
        out+=" ${C_D}${line:0:$((cols - 2))}${R}"$'\n'
        ((drawn++))
        printf '%s' "$out" > /dev/tty

        key=$(_m_key)
        case "$key" in
            up|k)    i=$cur; while (( i > 0 )); do ((i--)); _m_ok "$i" && { cur=$i; break; }; done
                     (( i == 0 )) && top=0 ;;   # at the top: scroll up to show the first heading
            down|j)  i=$cur; while (( i < n - 1 )); do ((i++)); _m_ok "$i" && { cur=$i; break; }; done ;;
            home|g)  cur=0; while (( cur < n - 1 )) && ! _m_ok "$cur"; do ((cur++)); done; top=0 ;;
            end|G)   cur=$((n - 1)); while (( cur > 0 )) && ! _m_ok "$cur"; do ((cur--)); done ;;
            pgup)    cur=$(( cur - vis )); (( cur < 0 )) && cur=0
                     while (( cur < n - 1 )) && ! _m_ok "$cur"; do ((cur++)); done ;;
            pgdn)    cur=$(( cur + vis )); (( cur >= n )) && cur=$((n - 1))
                     while (( cur > 0 )) && ! _m_ok "$cur"; do ((cur--)); done ;;
            space|x) if [[ "$mode" == checks ]]; then
                         if [[ "${_M_ON[$cur]:-}" == 1 ]]; then _M_ON[$cur]=0; else _M_ON[$cur]=1; fi
                     fi ;;
            right|enter|l)
                     if [[ "$mode" == checks ]]; then
                         _M_RESULT=""
                         for (( i = 0; i < n; i++ )); do [[ "${_M_ON[$i]:-}" == 1 ]] && _M_RESULT+="$i "; done
                     else
                         _M_RESULT=$cur
                     fi
                     break ;;
            left|esc|h|q) _M_RESULT=""; break ;;
        esac
    done
    # clear what was drawn, show the cursor again
    printf '\e[%dA\r\e[J\e[?25h' "$drawn" > /dev/tty
    [[ "$key" == left || "$key" == esc || "$key" == h || "$key" == q ]] && return 1
    return 0
}

# Make sure an interrupted menu doesn't leave the cursor hidden
trap '{ printf "\e[?25h" > /dev/tty; } 2> /dev/null || true' EXIT
