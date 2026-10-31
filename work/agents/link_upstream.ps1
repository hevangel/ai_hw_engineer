$env:GH_CONFIG_DIR = "C:\Users\hevan\AppData\Roaming\GitHub CLI"

# --- PR #93: replace the "no upstream issue filed" line with the link ---
$body = (gh api repos/hevangel/ai_hw_engineer/pulls/93 --jq '.body') -join "`n"
$old = "- No upstream issue has been filed. The reproducer and the ruled-out matrix are ready to paste if the owner wants to file one."
$new = "- Upstream issue filed 2026-10-29: https://github.com/aionhw/xezim/issues/650 — same reproducer, same ruled-out matrix."
if (-not $body.Contains($old)) { throw "PR #93 anchor not found" }
$body = $body.Replace($old, $new)
Set-Content -Path work/agents/pr93-body.md -Value $body -Encoding utf8
gh api -X PATCH repos/hevangel/ai_hw_engineer/pulls/93 -F body=@work/agents/pr93-body.md --jq '"PR #93 updated: \(.updated_at)"'

# --- confirm ---
(gh api repos/hevangel/ai_hw_engineer/pulls/93 --jq '.body') -join "`n" | Select-String -Pattern 'issues/650' | ForEach-Object { "found: $($_.Line.Trim())" }
