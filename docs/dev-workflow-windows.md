# Windows editors with a WSL repo

## 2. Visual Studio

The Windows clone and the WSL repo point at each other as git remotes:

| Repo | Remote | URL |
| --- | --- | --- |
| Windows clone | `wsl` | `//wsl.localhost/Ubuntu/home/nam/Gaku` |
| WSL repo | `win` | `/mnt/c/Users/Nam/Desktop/Gaku` |

Only committed work moves, so commit before switching sides. Each side only fetches from the other. Never push into the
other repo, because pushing to its checked-out branch is refused.

### 2.1 WSL to Windows

The Windows `master` tracks `wsl/master`, so Git > Pull in Visual Studio fast-forwards it. From WSL, `make wsl_to_win`
does the same for the current WSL branch, which must be the branch checked out in the Windows clone. It only
fast-forwards and stops if the Windows clone has its own commits. `BRANCH=<name>` overrides the branch.

### 2.2 Windows to WSL

Commit in Visual Studio, then merge it into the current WSL branch:

```bash
make win_to_wsl                  # git fetch win && git merge win/<current branch>
make win_to_wsl BRANCH=<name>    # merge another Windows branch
```

### 2.3 Line endings

Git for Windows has `core.autocrlf=true` in its system config, so the Windows working tree has CRLF and commits
store LF. Run git in the Windows clone from Windows, not from WSL. Linux git ignores that setting and reports every
file as modified.

### 2.4 Setup on a new machine

```bash
# Windows (Git Bash or PowerShell)
git clone https://github.com/tuannamtruong/Gaku C:\Users\Nam\Desktop\Gaku
git config --global --add safe.directory '%(prefix)///wsl.localhost/Ubuntu/home/nam/Gaku'
git remote add wsl //wsl.localhost/Ubuntu/home/nam/Gaku
git fetch wsl
git branch -u wsl/master master

# WSL
git remote add win /mnt/c/Users/Nam/Desktop/Gaku
```

`safe.directory` is needed because Windows git refuses repos whose owner it cannot match, and files under
`\\wsl.localhost` are owned by the Linux user.
