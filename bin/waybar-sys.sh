#!/usr/bin/env bash
# waybar-sys.sh — CPU/GPU stats for the Waterbear Waybar layouts. Prints Waybar JSON.
#   cputemp | gpu | cpu-mini | gpu-mini | cpu-meter | gpu-meter
# The NVIDIA card is only queried while it's already awake, so the bar never wakes it up
# (that would drain the battery on hybrid laptops).

HOT=85   # °C: at or above this, the module gets the "hot" CSS class (shown red)

json() {  # json TEXT TOOLTIP CLASS
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$3"
}

cpu_temp() {  # whole °C, or empty
    local h name
    for h in /sys/class/hwmon/hwmon*; do
        name=$(cat "$h/name" 2>/dev/null)
        case "$name" in
            coretemp|k10temp|zenpower|cpu_thermal)
                [[ -r "$h/temp1_input" ]] && { echo $(( $(cat "$h/temp1_input") / 1000 )); return; } ;;
        esac
    done
}

cpu_usage() {  # % over a short sample
    local a b idle1 idle2 total1 total2
    read -ra a < <(head -1 /proc/stat)
    sleep 0.4
    read -ra b < <(head -1 /proc/stat)
    idle1=$(( a[4] + a[5] )); idle2=$(( b[4] + b[5] ))
    total1=0; total2=0
    for v in "${a[@]:1:8}"; do total1=$(( total1 + v )); done
    for v in "${b[@]:1:8}"; do total2=$(( total2 + v )); done
    local dt=$(( total2 - total1 )) di=$(( idle2 - idle1 ))
    (( dt > 0 )) && echo $(( (100 * (dt - di)) / dt )) || echo 0
}

# GPU: sets GPU_STATE (off|on|none), GPU_USE, GPU_TEMP, GPU_NAME
gpu_read() {
    GPU_STATE=none; GPU_USE=""; GPU_TEMP=""; GPU_NAME="GPU"
    local d
    for d in /sys/bus/pci/devices/*; do
        [[ "$(cat "$d/vendor" 2>/dev/null)" == 0x10de ]] || continue
        [[ "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] || continue
        GPU_NAME="NVIDIA"
        if [[ "$(cat "$d/power/runtime_status" 2>/dev/null)" != active ]]; then
            GPU_STATE=off; return
        fi
        if command -v nvidia-smi > /dev/null; then
            local out
            out=$(timeout 2 nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
            if [[ -n "$out" ]]; then
                GPU_USE="${out%%,*}"; GPU_USE="${GPU_USE// /}"
                GPU_TEMP="${out##*,}"; GPU_TEMP="${GPU_TEMP// /}"
                GPU_STATE=on; return
            fi
        fi
        GPU_STATE=off; return
    done
    # AMD GPUs expose usage and temperature in sysfs without waking anything
    for d in /sys/class/drm/card*/device; do
        if [[ -r "$d/gpu_busy_percent" ]]; then
            GPU_NAME="AMD"; GPU_USE=$(cat "$d/gpu_busy_percent")
            local t; t=$(cat "$d"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
            [[ -n "$t" ]] && GPU_TEMP=$(( t / 1000 ))
            GPU_STATE=on; return
        fi
    done
}

meter() {  # meter PERCENT -> |||·······  (10 cells)
    local p=$1 n i out=""
    n=$(( (p + 5) / 10 )); (( n > 10 )) && n=10
    for (( i = 0; i < 10; i++ )); do (( i < n )) && out+="|" || out+="·"; done
    printf '%s' "$out"
}

hot_class() { [[ -n "$1" && "$1" -ge $HOT ]] && echo hot || echo normal; }

case "$1" in
    cputemp)
        t=$(cpu_temp)
        [[ -n "$t" ]] && json "${t}°" "CPU ${t}°C" "$(hot_class "$t")" || json "" "" normal ;;
    cpu-mini)
        u=$(cpu_usage); t=$(cpu_temp)
        json "CPU ${u}%${t:+ ${t}°}" "CPU ${u}%${t:+, ${t}°C}" "$(hot_class "$t")" ;;
    cpu-meter)
        u=$(cpu_usage); t=$(cpu_temp)
        json "cpu[$(meter "$u")]${u}%${t:+ ${t}°C}" "CPU ${u}%${t:+, ${t}°C}" "$(hot_class "$t")" ;;
    gpu)
        gpu_read
        case $GPU_STATE in
            on)   json "${GPU_USE}% ${GPU_TEMP}°" "$GPU_NAME ${GPU_USE}%, ${GPU_TEMP}°C" "$(hot_class "$GPU_TEMP")" ;;
            off)  json "off" "$GPU_NAME is asleep (saving battery)" off ;;
            none) json "—" "No GPU stats available" off ;;
        esac ;;
    gpu-mini)
        gpu_read
        case $GPU_STATE in
            on)   json "GPU ${GPU_USE}% ${GPU_TEMP}°" "$GPU_NAME ${GPU_USE}%, ${GPU_TEMP}°C" "$(hot_class "$GPU_TEMP")" ;;
            off)  json "GPU off" "$GPU_NAME is asleep (saving battery)" off ;;
            none) json "GPU —" "No GPU stats available" off ;;
        esac ;;
    gpu-meter)
        gpu_read
        case $GPU_STATE in
            on)   json "gpu[$(meter "$GPU_USE")]${GPU_USE}% ${GPU_TEMP}°C" "$GPU_NAME ${GPU_USE}%, ${GPU_TEMP}°C" "$(hot_class "$GPU_TEMP")" ;;
            off)  json "gpu[off]" "$GPU_NAME is asleep (saving battery)" off ;;
            none) json "gpu[—]" "No GPU stats available" off ;;
        esac ;;
    *)
        echo "usage: $0 cputemp|gpu|cpu-mini|gpu-mini|cpu-meter|gpu-meter" >&2; exit 1 ;;
esac
