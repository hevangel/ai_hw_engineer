$env:GH_CONFIG_DIR = "C:\Users\hevan\AppData\Roaming\GitHub CLI"
$id = 6491896548
$body = gh api "repos/hevangel/ai_engineer/issues/comments/$id" --jq '.body'
if ($null -eq $body) { throw "could not read comment" }
$fixed = $body -replace '\[#93\]\(https://github\.com/hevangel/ai_hw_engineer/docs\)', '[#93](https://github.com/hevangel/ai_hw_engineer/pull/93)'
if ($fixed -eq $body) { "no change made" } else { "link fixed" }
Set-Content -Path work/agents/issue4-comment-final.md -Value $fixed -Encoding utf8
gh api -X PATCH "repos/hevangel/ai_engineer/issues/comments/$id" -F body=@work/agents/issue4-comment-final.md --jq '.updated_at'
