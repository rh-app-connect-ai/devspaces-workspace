#!/bin/bash
set -euo pipefail

LOGDIR="/tmp/workshop/log"
mkdir -p "$LOGDIR"

echo "=================================================="
echo "FINAL REPORT – $(date)"
echo "=================================================="

# Counters
declare -i total=0 running=0 success=0 fixed=0 skipped=0 error=0 pending=0

# for logfile in "$LOGDIR"/user*.txt; do
for logfile in $(ls "$LOGDIR"/user*.txt 2>/dev/null | sort -V); do
  [[ ! -f "$logfile" ]] && continue
  total+=1

  user=$(basename "$logfile" .txt)        # → user59

  if [[ ! -s "$logfile" ]]; then
    # File exists but is empty → definitely not finished
    echo -e "\033[33m$user → PENDING (empty log)\033[0m"
    pending+=1
    continue
  fi

  last_line=$(tail -1 "$logfile" | tr -d '\n')

  case "$last_line" in
    "SUCCESS")
      echo -e "\033[32m$user → SUCCESS\033[0m"
      success+=1
      ;;
    "FIXED")
      echo -e "\033[32m$user → FIXED\033[0m"
      fixed+=1
      ;;
    "SKIPPED")
      echo -e "\033[34m$user → SKIPPED\033[0m"
      skipped+=1
      ;;
    "ERROR"|"ERROR in "*)
      echo -e "\033[31m$user → $last_line\033[0m"
      error+=1
      ;;
    *)
      echo -e "\033[33m$user → PENDING / UNKNOWN (last line: '$last_line')\033[0m"
      pending+=1
      ;;
  esac
done

# Final summary
echo "=================================================="
echo "Summary:"
echo "  Total users processed : $total"
echo -e "  SUCCESS     : \033[32m$success\033[0m"
echo -e "  FIXED       : \033[32m$fixed\033[0m"
echo -e "  SKIPPED     : \033[34m$skipped\033[0m"
echo -e "  ERROR       : \033[31m$error\033[0m"
echo -e "  PENDING     : \033[33m$pending\033[0m"
echo "=================================================="

# Optional: exit non-zero if anything went wrong
(( error > 0 || pending > 0 )) && exit 1
exit 0