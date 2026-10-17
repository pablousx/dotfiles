# Alias catalog adapted from the pinned Oh My Zsh plugins (MIT).
# Source: https://github.com/ohmyzsh/ohmyzsh/tree/59a9740721b734835812121322d6fe4827b0853a/plugins
# License: ../licenses/oh-my-zsh.txt. Local aliases register first and take precedence.
# Literal expansions are registered without evaluating command substitutions at startup.
_dotfiles_register npmg 'npm i -g '
_dotfiles_register npmS 'npm i -S '
_dotfiles_register npmD 'npm i -D '
while IFS='|' read -r name expansion; do
    [[ -n "$name" && "$name" != \#* ]] || continue
    if [[ "$expansion" == "docker compose"* ]] && type -P docker-compose >/dev/null; then
        expansion="docker-compose${expansion#docker compose}"
    fi
    _dotfiles_register "$name" "$expansion"
done <<'PLUGIN_ALIASES'
# git
grt|cd "$(git rev-parse --show-toplevel || echo .)"
ggpur|_dotfiles_git_pull_rebase
g|git
ga|git add
gaa|git add --all
gapa|git add --patch
gau|git add --update
gav|git add --verbose
gwip|_dotfiles_git_wip
gam|git am
gama|git am --abort
gamc|git am --continue
gamscp|git am --show-current-patch
gams|git am --skip
gap|git apply
gapt|git apply --3way
gbs|git bisect
gbsb|git bisect bad
gbsg|git bisect good
gbsn|git bisect new
gbso|git bisect old
gbsr|git bisect reset
gbss|git bisect start
gbl|git blame -w
gb|git branch
gba|git branch --all
gbd|git branch --delete
gbD|git branch --delete --force
gbgd|LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '{print $1}' | xargs git branch -d
gbgD|LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '{print $1}' | xargs git branch -D
gbm|git branch --move
gbnm|git branch --no-merged
gbr|git branch --remote
ggsup|git branch --set-upstream-to=origin/"$(_dotfiles_git_current_branch)"
gbg|LANG=C git branch -vv | grep ": gone\]"
gco|git checkout
gcor|git checkout --recurse-submodules
gcb|git checkout -b
gcB|git checkout -B
gcd|git checkout "$(_dotfiles_git_develop_branch)"
gcm|git checkout "$(_dotfiles_git_main_branch)"
gcp|git cherry-pick
gcpa|git cherry-pick --abort
gcpc|git cherry-pick --continue
gclean|git clean --interactive -d
gcl|git clone --recurse-submodules
gclf|git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules
gcam|git commit --all --message
gcas|git commit --all --signoff
gcasm|git commit --all --signoff --message
gcs|git commit --gpg-sign
gcss|git commit --gpg-sign --signoff
gcssm|git commit --gpg-sign --signoff --message
gcmsg|git commit --message
gcsm|git commit --signoff --message
gc|git commit --verbose
gca|git commit --verbose --all
gca!|git commit --verbose --all --amend
gcan!|git commit --verbose --all --no-edit --amend
gcans!|git commit --verbose --all --signoff --no-edit --amend
gcann!|git commit --verbose --all --date=now --no-edit --amend
gc!|git commit --verbose --amend
gcn|git commit --verbose --no-edit
gcn!|git commit --verbose --no-edit --amend
gcf|git config --list
gcfu|git commit --fixup
gdct|git describe --tags $(git rev-list --tags --max-count=1)
gd|git diff
gdca|git diff --cached
gdcw|git diff --cached --word-diff
gds|git diff --staged
gdw|git diff --word-diff
gdup|git diff @{upstream}
gdt|git diff-tree --no-commit-id --name-only -r
gf|git fetch
gfa|git fetch --all --tags --prune --jobs=10
gfo|git fetch origin
gg|git gui citool
gga|git gui citool --amend
ghh|git help
glgg|git log --graph
glgga|git log --graph --decorate --all
glgm|git log --graph --max-count=10
glods|git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short
glod|git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"
glola|git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all
glols|git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat
glol|git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"
glo|git log --oneline --decorate
glog|git log --oneline --decorate --graph
gloga|git log --oneline --decorate --graph --all
glp|_dotfiles_git_log_prettily
glg|git log --stat
glgp|git log --stat --patch
gignored|git ls-files -v | grep "^[[:lower:]]"
gfg|git ls-files | grep
gm|git merge
gma|git merge --abort
gmc|git merge --continue
gms|git merge --squash
gmff|git merge --ff-only
gmom|git merge origin/"$(_dotfiles_git_main_branch)"
gmum|git merge upstream/"$(_dotfiles_git_main_branch)"
gmtl|git mergetool --no-prompt
gmtlvim|git mergetool --no-prompt --tool=vimdiff
gl|git pull
gpr|git pull --rebase
gprv|git pull --rebase -v
gpra|git pull --rebase --autostash
gprav|git pull --rebase --autostash -v
gprom|git pull --rebase origin "$(_dotfiles_git_main_branch)"
gpromi|git pull --rebase=interactive origin "$(_dotfiles_git_main_branch)"
gprum|git pull --rebase upstream "$(_dotfiles_git_main_branch)"
gprumi|git pull --rebase=interactive upstream "$(_dotfiles_git_main_branch)"
ggpull|git pull origin "$(_dotfiles_git_current_branch)"
gluc|git pull upstream "$(_dotfiles_git_current_branch)"
glum|git pull upstream "$(_dotfiles_git_main_branch)"
gp|git push
gpd|git push --dry-run
gpf!|git push --force
gpf|git push --force-with-lease --force-if-includes
gpsup|git push --set-upstream origin "$(_dotfiles_git_current_branch)"
gpsupf|git push --set-upstream origin "$(_dotfiles_git_current_branch)" --force-with-lease --force-if-includes
gpv|git push --verbose
gpoat|git push origin --all && git push origin --tags
gpod|git push origin --delete
ggpush|git push origin "$(_dotfiles_git_current_branch)"
gpu|git push upstream
grb|git rebase
grba|git rebase --abort
grbc|git rebase --continue
grbi|git rebase --interactive
grbo|git rebase --onto
grbs|git rebase --skip
grbd|git rebase "$(_dotfiles_git_develop_branch)"
grbm|git rebase "$(_dotfiles_git_main_branch)"
grbom|git rebase origin/"$(_dotfiles_git_main_branch)"
grbum|git rebase upstream/"$(_dotfiles_git_main_branch)"
grf|git reflog
gr|git remote
grv|git remote --verbose
gra|git remote add
grrm|git remote remove
grmv|git remote rename
grset|git remote set-url
grup|git remote update
grh|git reset
gru|git reset --
grhh|git reset --hard
grhk|git reset --keep
grhs|git reset --soft
gpristine|git reset --hard && git clean --force -dfx
gwipe|git reset --hard && git clean --force -df
groh|git reset origin/"$(_dotfiles_git_current_branch)" --hard
grs|git restore
grss|git restore --source
grst|git restore --staged
gunwip|git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1
grev|git revert
greva|git revert --abort
grevc|git revert --continue
grm|git rm
grmc|git rm --cached
gcount|git shortlog --summary --numbered
gsh|git show
gsps|git show --pretty=short --show-signature
gstall|git stash --all
gstaa|git stash apply
gstc|git stash clear
gstd|git stash drop
gstl|git stash list
gstp|git stash pop
gsta|git stash push
gsts|git stash show --patch
gst|git status
gss|git status --short
gsb|git status --short --branch
gsi|git submodule init
gsu|git submodule update
gsd|git svn dcommit
git-svn-dcommit-push|git svn dcommit && git push github "$(_dotfiles_git_main_branch)":svntrunk
gsr|git svn rebase
gsw|git switch
gswc|git switch --create
gswd|git switch "$(_dotfiles_git_develop_branch)"
gswm|git switch "$(_dotfiles_git_main_branch)"
gta|git tag --annotate
gts|git tag --sign
gtv|git tag | sort -V
gignore|git update-index --assume-unchanged
gunignore|git update-index --no-assume-unchanged
gwch|git log --patch --abbrev-commit --pretty=medium --raw
gwt|git worktree
gwta|git worktree add
gwtls|git worktree list
gwtmv|git worktree move
gwtrm|git worktree remove
gstu|git stash push --include-untracked
gtl|_dotfiles_git_tag_list
gk|_dotfiles_git_gui
gke|_dotfiles_git_gui_reflog
# docker-compose
dco|docker compose
dcb|docker compose build
dce|docker compose exec
dcps|docker compose ps
dcrestart|docker compose restart
dcrm|docker compose rm
dcr|docker compose run
dcstop|docker compose stop
dcup|docker compose up
dcupb|docker compose up --build
dcupd|docker compose up -d
dcupdb|docker compose up -d --build
dcdn|docker compose down
dcl|docker compose logs
dclf|docker compose logs -f
dclF|docker compose logs -f --tail 0
dcpull|docker compose pull
dcstart|docker compose start
dck|docker compose kill
# npm
npmF|npm i -f
npmE|PATH="$(npm prefix)/node_modules/.bin:$PATH"
npmO|npm outdated
npmU|npm update
npmV|npm -v
npmL|npm list
npmL0|npm ls --depth=0
npmst|npm start
npmt|npm test
npmR|npm run
npmP|npm publish
npmI|npm init
npmi|npm info
npmSe|npm search
npmrd|npm run dev
npmrb|npm run build
# yarn
y|yarn
ya|yarn add
yad|yarn add --dev
yap|yarn add --peer
yb|yarn build
ycc|yarn cache clean
yd|yarn dev
yf|yarn format
yh|yarn help
yi|yarn init
yin|yarn install
yln|yarn lint
ylnf|yarn lint --fix
yp|yarn pack
yrm|yarn remove
yrun|yarn run
ys|yarn serve
yst|yarn start
yt|yarn test
ytc|yarn test --coverage
yui|yarn upgrade-interactive
yup|yarn upgrade
yv|yarn version
yw|yarn workspace
yws|yarn workspaces
yy|yarn why
yuil|yarn upgrade-interactive --latest
yii|yarn install --frozen-lockfile
yifl|yarn install --frozen-lockfile
ydlx|yarn dlx
yn|yarn node
yga|yarn global add
ygls|yarn global list
ygrm|yarn global remove
ygu|yarn global upgrade
yls|yarn list
yout|yarn outdated
yuca|yarn global upgrade && yarn cache clean
# history
h|builtin history
hl|builtin history | less
hs|builtin history | grep
hsi|builtin history | grep -i
# encode64
e64|_dotfiles_encode64
ef64|_dotfiles_encodefile64
d64|_dotfiles_decode64
# Public helper functions used alongside the aliases
git_current_branch|_dotfiles_git_current_branch
current_branch|_dotfiles_git_current_branch
git_main_branch|_dotfiles_git_main_branch
git_develop_branch|_dotfiles_git_develop_branch
grename|_dotfiles_git_rename
gunwipall|_dotfiles_git_unwip_all
work_in_progress|_dotfiles_git_work_in_progress
ggpnp|_dotfiles_git_pull_push
gbda|_dotfiles_git_delete_merged
gbds|_dotfiles_git_delete_squashed
gccd|_dotfiles_git_clone_cd
gdv|_dotfiles_git_diff_view
gdnolock|_dotfiles_git_diff_no_lock
ggu|_dotfiles_git_pull_rebase
ggl|_dotfiles_git_pull_current
ggf|_dotfiles_git_push_force
ggfl|_dotfiles_git_push_lease
ggp|_dotfiles_git_push_current
encode64|_dotfiles_encode64
decode64|_dotfiles_decode64
encodefile64|_dotfiles_encodefile64
extract|_dotfiles_helper extract
PLUGIN_ALIASES
