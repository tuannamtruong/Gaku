# Publishing the wiki

The GitHub wiki is a rendered copy of `docs/`, not a place to write. Every page is generated from a
markdown file in this repository and republished by
[`.github/workflows/publish-wiki.yml`](../../.github/workflows/publish-wiki.yml) on each push to
`master` that touches `docs/`. Anything typed into the wiki's browser editor survives until the next
publish and no longer.

The arrangement exists so documentation travels with the code it describes: it goes through pull
request review, it can be changed in the same commit as the behaviour it documents, and it cannot
quietly drift the way a hand-edited wiki does.

## 1. How it works

Three pieces:

| Path | Role |
| --- | --- |
| `docs/wiki/manifest.txt` | Maps each source file to its wiki page name |
| `docs/wiki/{Home,_Sidebar,_Footer}.md` | Wiki-only pages, copied verbatim |
| `scripts/publish-wiki.sh` | Builds the wiki tree from those two inputs |

The workflow clones the wiki repository, runs the script against that checkout, and commits
whatever changed. The script does the whole build; the workflow only moves git around. That split
means you can see exactly what a publish would do without triggering one:

```bash
./scripts/publish-wiki.sh /tmp/wiki-preview
```

The script deletes every markdown file in the target before writing, so a page removed from the
manifest is removed from the wiki.

## 2. Adding a page

1. Write the document under `docs/` as normal.
2. Add a line to [`manifest.txt`](manifest.txt): source path, a pipe, and the page name.
3. Add a link to [`_Sidebar.md`](_Sidebar.md) under the right heading — the sidebar is hand-kept, since
   ordering and grouping are editorial choices a script cannot make.
4. Preview with the command above, then open a pull request.

Page names are the page titles. `Architecture-Overview` publishes to `/wiki/Architecture-Overview`
and displays as "Architecture Overview" — hyphens become spaces. The wiki namespace is flat, so
express hierarchy in the name (`CICD-Workflow`, `CICD-Roadmap`) rather than in directories.

A manifest entry pointing at a file that does not exist fails the publish, which is what catches a
renamed document. An entry pointing at an empty file is skipped with a warning, so a placeholder
like `docs/infrastructure.md` can sit in the manifest until someone writes it.

## 3. What not to write in a published doc

**Relative links.** A link like `[the schema](database.md)` works in the GitHub repo view and
resolves to nothing in the wiki, because the published file sits in a different repository with a
flat layout. Link to another page by its wiki name — `[Database Schema](Database-Schema)` — or use
an absolute `https://github.com/...` URL for anything outside the wiki. The script warns on every
link it believes will break, and those warnings appear in the workflow log.

**Anything secret.** The wiki of a public repository is public, and it has its own history. A
credential committed to `docs/` and published is exposed in two repositories, and scrubbing the
source repository does not scrub the wiki.

## 4. First-time setup

The wiki repository does not exist until a first page is created by hand — the workflow's clone
step is what fails when it has not been. Once, before the first publish:

1. Repository → Settings → Features → tick **Wikis**.
2. Open the Wiki tab and create the first page with any content. The publish overwrites it.
3. Settings → Features → Wikis → tick **Restrict editing to collaborators only**, so drive-by edits
   cannot silently accumulate in a copy that gets overwritten anyway.

The workflow authenticates with the automatic `GITHUB_TOKEN` and needs no configured secret. If the
push is rejected with a 403, the wiki did not inherit the workflow's `contents: write` permission —
create a fine-grained personal access token with wiki write access, store it as a repository secret,
and swap it in for `secrets.GITHUB_TOKEN` in the clone step.
