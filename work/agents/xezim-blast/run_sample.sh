#!/usr/bin/env bash
# Re-run the xezim sample for the comparators most similar to tb_ttl_74x679.
# NOT EXECUTED in the reporting session (no command-execution tool was
# available). Run this from B:\ai_hw_engineer in Git Bash / WSL bash.
#
#   bash work/agents/xezim-blast/run_sample.sh
#
# Results land in work/agents/xezim-blast/sample-results.txt
set -u

OUT="work/agents/xezim-blast/sample-results.txt"
: > "$OUT"

# tb name == module name (tb_ttl_74x677 -> ttl_74x677)
SAMPLE="
tb_ttl_74x677
tb_ttl_74x678
tb_ttl_74x679
tb_ttl_74x680
tb_ttl_74x681
tb_ttl_74x716
tb_ttl_74x44
tb_ttl_74x85
tb_ttl_74x189
tb_ttl_74x16209
"

for tb in $SAMPLE; do
  module="${tb#tb_}"
  printf '=== %s ===\n' "$tb" | tee -a "$OUT"
  docker run --rm -v "B:\\ai_hw_engineer:/workspace" -w /workspace \
    ai-hw-engineer:latest sh -c \
    "cd design/ttl_74xx && xezim --simulate --sv2017 --error-exit --max-time 100ms -s ${tb} src/${module}.sv tb/${tb}.sv" \
    2>&1 | tail -25 | tee -a "$OUT"
  printf 'exit=%s\n\n' "${PIPESTATUS[0]}" | tee -a "$OUT"
done

echo "wrote $OUT"
