#!/usr/bin/env python3
"""Audit Bash aliases against an independently captured, pinned Zsh catalog."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = json.loads((ROOT / 'tests/fixtures/zsh-plugin-aliases.json').read_text())
MANIFEST = (ROOT / 'profiles/zsh/modules/plugins.txt').read_text()
assert hashlib.sha256(MANIFEST.encode()).hexdigest() == FIXTURE['manifest_sha256'], (
    'Zsh plugin manifest changed; audit alias coverage and refresh the fixture')


def shell(script, home, **extra):
    env = dict(os.environ, HOME=str(home), DOTFILES_DIR=str(ROOT), **extra)
    env.pop('BASH_ENV', None)
    return subprocess.run(['bash', '--noprofile', '--norc', '-c', script],
                          env=env, check=True, stdout=subprocess.PIPE).stdout


if int(subprocess.check_output(['bash', '-c', 'printf %s "${BASH_VERSINFO[0]}"'])) < 5:
    print('skip - plugin alias parity requires Omarchy Bash 5')
    raise SystemExit

with tempfile.TemporaryDirectory() as temporary:
    home = Path(temporary)
    # Inspect alias values as data; never evaluate them to build expectations.
    output = shell('''
shopt -s expand_aliases
source "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash"
for name in "${!BASH_ALIASES[@]}"; do
    printf '%s\\0%s\\0' "$name" "${BASH_ALIASES[$name]}"
done
''', home).decode().split('\0')
    actual = dict(zip(output[0::2], output[1::2]))
    adaptations = {
        'ggpur': '_dotfiles_git_pull_rebase', 'gwip': '_dotfiles_git_wip',
        'glp': '_dotfiles_git_log_prettily', 'gstu': 'git stash push --include-untracked',
        'gtl': '_dotfiles_git_tag_list', 'gk': '_dotfiles_git_gui', 'gke': '_dotfiles_git_gui_reflog',
        'npmE': 'PATH="$(npm prefix)/node_modules/.bin:$PATH"',
        'e64': '_dotfiles_encode64', 'd64': '_dotfiles_decode64', 'ef64': '_dotfiles_encodefile64',
        'h': 'builtin history', 'hl': 'builtin history | less',
        'hs': 'builtin history | grep', 'hsi': 'builtin history | grep -i',
    }
    # Zsh sources the local alias file last: these win over the Yarn plugin.
    local_aliases = (ROOT / 'profiles/zsh/modules/aliases.zsh').read_text()
    for name in ('yi', 'yd', 'yb', 'ys'):
        adaptations[name] = re.search(r'^alias ' + name + r'="([^"]+)"$', local_aliases, re.M)[1]
    count = 0
    for plugin, source in FIXTURE['plugins'].items():
        assert re.search(r'^ohmyzsh/ohmyzsh path:plugins/' + re.escape(plugin)
                         + r' pin:' + source['commit'] + r'$', MANIFEST, re.M), (
                             plugin, 'Pinned source changed; audit and refresh the parity fixture')
        for name, variants in source['aliases'].items():
            expected = variants[0] if plugin == 'git' else variants[-1]
            expected = expected.replace('$dccmd', 'docker-compose' if shutil.which('docker-compose') else 'docker compose')
            if plugin == 'git':
                for function in ('git_main_branch', 'git_develop_branch', 'git_current_branch'):
                    expected = expected.replace('$(' + function + ')', '$(_dotfiles_' + function + ')')
                if '$(_dotfiles_git_' in expected and '"$(_dotfiles_git_' not in expected:
                    expected = re.sub(r'\$\(_dotfiles_git_\w+\)', r'"\g<0>"', expected)
            expected = adaptations.get(name, expected)
            assert actual.get('df-' + name) == expected, (plugin, name, actual.get('df-' + name), expected)
            count += 1
    for names in FIXTURE['existing_utility_aliases'].values():
        for name in names:
            assert 'df-' + name in actual, name
    # Test the entire namespace against pre-existing user aliases, including df- names.
    shell('''
shopt -s expand_aliases
source "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash"
for name in "${!BASH_ALIASES[@]}"; do alias "$name=printf user-owned"; done
source "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash"
for name in "${!BASH_ALIASES[@]}"; do [[ ${BASH_ALIASES[$name]} == 'printf user-owned' ]] || exit 1; done
''', home)
    shell('''
set -e
shopt -s expand_aliases
# Names used by one shortcut must not redirect another shortcut into user code.
alias gsta='false'
ggl() { return 99; }
ggp() { return 99; }
git_main_branch() { printf wrong-branch; }
source "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash"
git() { printf '<%s>\\n' "$@"; }
[[ $(gf 'remote with spaces') == $'<fetch>\\n<remote with spaces>' ]]
[[ $(df-gfa) == $'<fetch>\\n<--all>\\n<--tags>\\n<--prune>\\n<--jobs=10>' ]]
[[ $(df-gstu) == $'<stash>\\n<push>\\n<--include-untracked>' ]]
[[ $(df-gpf) == $'<push>\\n<--force-with-lease>\\n<--force-if-includes>' ]]
[[ $(df-ggpnp 'branch name') == $'<pull>\\n<origin>\\n<branch name>\\n<push>\\n<origin>\\n<branch name>' ]]
[[ $(df-gdnolock --cached) == $'<diff>\\n<--cached>\\n<:(exclude)package-lock.json>\\n<:(exclude)*.lock>' ]]
[[ $(df-glp '%h %s') == $'<log>\\n<--pretty=%h %s>' ]]
[[ $(df-gtl 'v[1]') == $'<tag>\\n<--sort=-v:refname>\\n<-n>\\n<--list>\\n<v[1]*>' ]]
# Failure of a prerequisite must prevent the destructive follow-up operation.
git() { printf '%s\\n' "$*" >> "$HOME/git-calls"; return 1; }
if df-grename before after; then exit 1; fi
[[ $(cat "$HOME/git-calls") == 'branch -m before after' ]]
: > "$HOME/git-calls"
if df-gwip; then exit 1; fi
[[ $(cat "$HOME/git-calls") == 'add --all' ]]
: > "$HOME/git-calls"
if df-ggpnp feature; then exit 1; fi
[[ $(cat "$HOME/git-calls") == 'pull origin feature' ]]
npm() { printf '<%s>\\n' "$@"; }
yarn() { printf '<%s>\\n' "$@"; }
docker() { printf '<%s>\\n' "$@"; }
[[ $(df-npmD 'package name') == $'<i>\\n<-D>\\n<package name>' ]]
[[ $(df-yad 'package name') == $'<add>\\n<--dev>\\n<package name>' ]]
[[ $(df-yi) == '<install>' && $(df-ys) == '<start>' ]]
if [[ ${BASH_ALIASES[df-dco]} == 'docker compose' ]]; then
    [[ $(df-dcupdb 'service name') == $'<compose>\\n<up>\\n<-d>\\n<--build>\\n<service name>' ]]
fi
# binary-safe base64 helpers, including paths with spaces
printf '\\0binary\\377' > "$HOME/input file"
df-ef64 "$HOME/input file" >/dev/null
df-d64 < "$HOME/input file.txt" > "$HOME/decoded"
cmp "$HOME/input file" "$HOME/decoded"
''', home)
    # Real Git is used only in disposable repositories; no remotes are contacted.
    shell('''
set -e
shopt -s expand_aliases
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
source "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash"
mkdir "$HOME/repository space"
cd "$HOME/repository space"
git init -q --initial-branch=master
git -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m initial
[[ $(df-git_main_branch) == master ]]
git branch -m main
git branch feature
git branch develop
git checkout -q feature
[[ $(df-git_main_branch) == main && $(df-git_develop_branch) == develop ]]
[[ $(df-git_current_branch) == feature ]]
df-gcm >/dev/null 2>&1
[[ $(git branch --show-current) == main ]]
df-gcd >/dev/null 2>&1
[[ $(git branch --show-current) == develop ]]
git checkout -q --detach
[[ $(df-git_current_branch) == "$(git rev-parse --short HEAD)" ]]
git checkout -q main
# Merged-branch cleanup must retain the main/develop branches and unmerged work.
git branch merged
git checkout -q -b unmerged
printf work > work
git add work
git -c user.name=Test -c user.email=test@example.invalid commit -q -m unmerged
git checkout -q main
df-gbda >/dev/null
! git show-ref --quiet --verify refs/heads/merged
git show-ref --quiet --verify refs/heads/develop
git show-ref --quiet --verify refs/heads/unmerged
# Squashed-branch detection must remove only work already merged into main.
git checkout -q -b squashed
printf squashed > squashed
git add squashed
git -c user.name=Test -c user.email=test@example.invalid commit -q -m squashed
git checkout -q main
git merge --squash squashed >/dev/null
git -c user.name=Test -c user.email=test@example.invalid commit -q -m squash-merge
GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid \
GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid df-gbds >/dev/null
! git show-ref --quiet --verify refs/heads/squashed
git show-ref --quiet --verify refs/heads/unmerged
# Unwip stops at the last normal commit.
base=$(git rev-parse HEAD)
git -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m '--wip-- first'
git -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m '--wip-- second'
[[ $(df-work_in_progress) == 'WIP!!' ]]
df-gunwipall >/dev/null
[[ $(git rev-parse HEAD) == "$base" ]]
git branch -m release
git update-ref refs/remotes/origin/release HEAD
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/release
[[ $(df-git_main_branch) == release ]]
# Clone-and-cd preserves arguments and only changes directory after success.
cd "$HOME"
df-gccd --branch release "$HOME/repository space" 'cloned space' >/dev/null 2>&1
[[ $PWD == "$HOME/cloned space" ]]
previous=$PWD
if df-gccd "$HOME/does-not-exist" failed >/dev/null 2>&1; then exit 1; fi
[[ $PWD == "$previous" ]]
''', home)
    # Compose detection supports both implementations without executing either at startup.
    bindir = home / 'bin'
    bindir.mkdir()
    compose = bindir / 'docker-compose'
    compose.write_text('#!/bin/sh\nprintf "<%s>\\n" "$@"\n')
    compose.chmod(0o755)
    shell('''
set -e
shopt -s expand_aliases
source "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash"
[[ ${BASH_ALIASES[df-dco]} == docker-compose ]]
[[ $(df-dcupdb 'service name') == $'<up>\\n<-d>\\n<--build>\\n<service name>' ]]
''', home, PATH=str(bindir) + ':' + os.environ['PATH'])
print(f'ok - {count} pinned plugin aliases, local overrides, collisions, arguments and Git behavior')
