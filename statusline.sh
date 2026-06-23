#!/usr/bin/env bash
input=$(cat)
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
fiveh=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
total=$((total_in + total_out))

fmt_tok() { awk -v n="$1" 'BEGIN{if(n>=1000000)printf"%.1fM",n/1000000;else if(n>=1000)printf"%.0fk",n/1000;else printf"%d",n}'; }

# ANSI palette
DIM=$'\033[2;37m'    # dim grey — labels
SEP=$'\033[2;37m'    # dim separator
EMP=$'\033[2;37m'    # empty bar
B=$'\033[1m'         # bold
R=$'\033[0m'         # reset
# muted palette (256-color, non-bold): soft sage / gold / amber / rose
GRN=$'\033[38;5;108m'   # soft sage green
YEL=$'\033[38;5;179m'   # muted gold
ORG=$'\033[38;5;173m'   # soft amber
RED=$'\033[38;5;167m'   # soft rose-red
# rate-limit color: green < 50, yellow >= 50, orange >= 80, red >= 90
hue() { awk -v p="$1" -v g="$GRN" -v y="$YEL" -v o="$ORG" -v r="$RED" 'BEGIN{if(p>=90)print r;else if(p>=80)print o;else if(p>=50)print y;else print g}'; }
# context color: green < 10, yellow >= 10, orange >= 15, red >= 20
hue_ctx() { awk -v p="$1" -v g="$GRN" -v y="$YEL" -v o="$ORG" -v r="$RED" 'BEGIN{if(p>=20)print r;else if(p>=15)print o;else if(p>=10)print y;else print g}'; }
# reasoning-effort color: green = low, yellow = medium, red = high/xhigh/max
hue_eff() { case "$1" in low) echo "$GRN";; medium) echo "$YEL";; high|xhigh|max) echo "$RED";; *) echo "$DIM";; esac; }

# context bar, colored by fill level
bar=""
if [ -n "$used" ]; then
  c=$(hue_ctx "$used")
  filled=$(awk -v u="$used" 'BEGIN{f=int(u/10+0.5);if(f<0)f=0;if(f>10)f=10;print f}')
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if [ "$i" -le "$filled" ]; then bar="${bar}${c}█${R}"; else bar="${bar}${EMP}░${R}"; fi
  done
fi

# tokens used/max — used bright, /max dim
tok="${B}$(fmt_tok "$total")${R}"
if [ -n "$used" ] && [ "$total" -gt 0 ]; then
  max=$(awk -v t="$total" -v u="$used" 'BEGIN{if(u>0)printf"%.0f",t*100/u;else print 0}')
  tok="${tok}${DIM}/$(fmt_tok "$max")${R}"
fi

sep="${SEP} │ ${R}"
out=""
# reasoning effort — minimalist colored dot + level, leads the line
if [ -n "$effort" ]; then
  ec=$(hue_eff "$effort")
  out="${ec}●${R} ${ec}${effort}${R}${sep}"
fi
[ -n "$used" ] && out="${out}$(printf "%s $(hue_ctx "$used")%.0f%%${R}" "$bar" "$used")"
out="${out}  ${tok}"
[ -n "$fiveh" ] && out="${out}${sep}${DIM}5h${R} $(hue "$fiveh")$(printf '%.0f' "$fiveh")%${R}"
[ -n "$week" ]  && out="${out}${sep}${DIM}7d${R} $(hue "$week")$(printf '%.0f' "$week")%${R}"
echo "$out"
