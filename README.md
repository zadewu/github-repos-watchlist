# Github Repos Watchlist

A plaintext log of my starred GitHub repositories. Git history records when each repo was starred or unstarred.

- Data: [`zadewu.starred.csv`](zadewu.starred.csv) (newest star first)
- Updated 3× a day (12:23, 18:23, 00:23 Asia/Saigon) by [`.github/workflows/collect-stars.yaml`](.github/workflows/collect-stars.yaml), which runs [`scripts/fetch-stars.sh`](scripts/fetch-stars.sh)
- See when a repo was starred or unstarred: `git log -p -S '<owner>/<repo>' -- zadewu.starred.csv`

Run locally (needs `gh` and `jq`): `bash scripts/fetch-stars.sh zadewu`

Adapted from [Genzer/starred-github-repos](https://github.com/Genzer/starred-github-repos).

## Mirroring stars from another account

Each run first stars on `zadewu` every repo that the account in `SOURCE_GITHUB_HANDLE` (my work account) has starred. It's **add-only**: unstarring on the work account changes nothing here. A large backlog is spread over runs (`MAX_STARS_PER_RUN`, default 300).

These are real stars on the `zadewu` account, made through the GitHub API with zadewu's own token. The work account is only read (its public star list), and no work credentials are used.

## Setup

| Name | Kind | Required for | Value |
|---|---|---|---|
| `GITHUB_TOKEN` | built-in | CSV export | Nothing to do. Actions provides it |
| `ZADEWU_STAR_TOKEN` | **Secret** | Mirroring | Fine-grained PAT owned by `zadewu` (see below) |
| `SOURCE_GITHUB_HANDLE` | **Variable** | Mirroring | Work account GitHub handle. If unset, mirroring is skipped |

### 1. Create the zadewu token
Logged in as **zadewu**: Settings → Developer settings → Personal access tokens → **Fine-grained tokens** → Generate new token.
- Resource owner: `zadewu`
- Expiration: up to 1 year. Set a reminder to rotate it
- Repository access: **Public repositories**
- Account permissions: **Starring → Read and write**. Leave everything else at *No access*

Check it belongs to zadewu: `GH_TOKEN=<token> gh api /user --jq .login` should print `zadewu`.

### 2. Add the secret and the variable
In this repo: Settings → Secrets and variables → **Actions**
- **Secrets** tab → New repository secret: name `ZADEWU_STAR_TOKEN`, value = the token
- **Variables** tab → New repository variable: name `SOURCE_GITHUB_HANDLE`, value = the work handle

Or with `gh`, from this repo:
```sh
gh secret set ZADEWU_STAR_TOKEN          # paste the token when prompted
gh variable set SOURCE_GITHUB_HANDLE --body '<work-handle>'
```

### 3. Allow the workflow to push
Settings → Actions → General → Workflow permissions → **Read and write permissions**. The workflow commits the CSV with the built-in `GITHUB_TOKEN`.

### 4. Run it
```sh
gh workflow run collect-stars.yaml && gh run watch
```
The mirror step prints `missing=… starred=… skipped=…`. A backlog over 300 finishes over the next scheduled runs (300 per run), or sooner if you re-run the workflow.

Preview locally without changing anything: `DRY_RUN=TRUE GH_TOKEN=<zadewu-token> bash scripts/sync-stars.sh <work-handle>`

### Stopping the mirror
Delete the `SOURCE_GITHUB_HANDLE` variable, for example when leaving the job. The mirror step is skipped, the CSV export keeps running, and stars already added stay on zadewu.
