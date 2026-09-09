# GitHub wiki

The GitHub wiki is a rendered copy of `docs/`.

## 1. How it works

| Path | Role |
| --- | --- |
| `docs/wiki/manifest.txt` | Maps each doc to its wiki page name |
| `docs/wiki/{Home,_Sidebar,_Footer}.md` | Wiki-only pages, copied verbatim |
| `scripts/publish-wiki.sh` | Builds the wiki tree from those two inputs |

The workflow clones the wiki repository, runs the script against that checkout, and commits
whatever changed. The script does the whole build; the workflow only moves git around.

## 2. Adding a page

1. Add a doc in `docs/`.
2. Add a line to [`manifest.txt`](manifest.txt): source path, a pipe, and the page name.
3. Add a link to [`_Sidebar.md`](_Sidebar.md) under the right heading.
4. Preview.
```bash
./scripts/publish-wiki.sh /tmp/wiki-preview
```
5. Open a pull request.

Page names are the page titles. `Architecture-Overview` publishes to `/wiki/Architecture-Overview`
and displays as "Architecture Overview" with hyphens become spaces. The wiki namespace is flat, so
express hierarchy in the name (`CICD-Workflow`, `CICD-Roadmap`) rather than in directories.

## 3. First-time setup

Once, before the first publish:

1. Repository → Settings → Features → tick **Wikis**.
2. Open the Wiki tab and create the first page with any content. This will be overwritten by a real publish.
3. Settings → Features → Wikis → tick **Restrict editing to collaborators only**.