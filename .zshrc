source ~/.zshrc.zplug
export LANG=ja_JP.UTF-8

# emacs bind
bindkey -e

##################
# autoload
##################
autoload -Uz colors
colors

autoload -Uz compinit
compinit -C

autoload -Uz add-zsh-hook
autoload -Uz chpwd_recent_dirs cdr

autoload -Uz vcs_info

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

alias vim=nvim


bindkey '^r' history-incremental-pattern-search-backward
bindkey '^s' history-incremental-pattern-search-forward

autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^b" history-beginning-search-forward-end

add-zsh-hook chpwd chpwd_recent_dirs
zstyle ":chpwd:*" recent-dirs-default true

export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/bin:$HOME/.anyenv/bin:$GOPATH/bin
export JAVA_HOME=`/usr/libexec/java_home -v 1.8`

eval "$(anyenv init -)"

# zaw
bindkey '^[d' zaw-cdr
bindkey '^[f' zaw-git-files
bindkey '^[b' zaw-git-branches
bindkey '^[@' zaw-gitdir
bindkey '^[a' zaw-tmux

##################
# zstyles
##################
# vcs_infoの設定
zstyle ':vcs_info:*' enable git svn
zstyle ':vcs_info:*' formats '(%s)[%b] '
zstyle ':vcs_info:*' actionformats '(%s)[%b|%a] '
zstyle ':vcs_info:svn:*' branchformat '%b:r%r'


zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr "+"
zstyle ':vcs_info:git:*' unstagedstr "-"
zstyle ':vcs_info:git:*' formats '(%s)[%b]%c%u'
zstyle ':vcs_info:git:*' actionformats '(%s)[%b|%a]%c%u'

# 補完
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' group-name ''
## 補完候補が2つ以上なければ即補完
zstyle ':completion:*:default' menu select=2
zstyle ':completion:*' list-colors "%{{s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

## 補完候補をキャッシュ
zstyle ':completion:*' keep-prefix
zstyle ':completion:*' recent-dirs-insert both

zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path ~/.zsh/cache

##################
# func
##################
function zaw-src-gitdir () {
  _dir=$(git rev-parse --show-cdup 2>/dev/null)
  if [ $? -eq 0 ]
  then
    candidates=( $(git ls-files ${_dir} | perl -MFile::Basename -nle \
                                               '$a{dirname $_}++; END{delete $a{"."}; print for sort keys %a}') )
  fi
  actions=("zaw-src-gitdir-cd")
  act_descriptions=("change directory in git repos")
}

function zaw-src-gitdir-cd () {
  BUFFER="cd $1"
  zle accept-line
}
zaw-register-src -n gitdir zaw-src-gitdir

# git statusをpromptに表示させるため
function _update_vcs_info_msg {
    psvar=()
    STY= LANG=en_US.UTF-8 && vcs_info
    if [[ -z ${vcs_info_msg_0_} ]]; then
        psvar[1]=""
        psvar[2]=""
        psvar[3]=""
    else
        [[ -n "$vcs_info_msg_0_" ]] && psvar[1]="$vcs_info_msg_0_ "
        [[ -n "$vcs_info_msg_1_" ]] && psvar[2]="$vcs_info_msg_1_ "
        [[ -n "$vcs_info_msg_2_" ]] && psvar[3]="$vcs_info_msg_2_ "
    fi
}

##################
# setopts
##################
# ビープ音を鳴らさない
setopt no_beep

setopt no_nomatch
# prompt内で変数展開など
setopt prompt_subst
# prompt実行中は右promptを隠す
setopt transient_rprompt
# 直前と同じコマンドラインはヒストリーに追加しない
setopt hist_ignore_dups
# 重複したヒストリーは追加しない
setopt hist_ignore_all_dups
# スペースから始まるコマンドはヒストリーに追加しない
setopt hist_reduce_blanks

setopt hist_no_store

setopt hist_no_store

setopt hist_verify
# シェルのプロセスごとに履歴を共有j
setopt share_history
# ディレクトリ名だけで移動
setopt auto_cd
# cdしたらpushd
setopt auto_pushd
# 補完候補が複数あるときに、一覧表示
setopt auto_list
# 補完候補が複数あるときに自動的に一覧表示
setopt auto_menu

setopt list_packed
setopt list_types
setopt no_flow_control
setopt print_eight_bit
setopt pushd_ignore_dups
setopt rec_exact
setopt autoremoveslash
unsetopt list_beep
# カーソル位置で補完する
setopt complete_in_word

setopt glob
# globを展開せずに一覧から補完
setopt glob_complete
# 拡張globを有効
setopt extended_glob
# globでパスを生成したときに、パスがディレクトリの場合は/をつける
setopt mark_dirs
# 辞書順でなく数値順に並べる
setopt numeric_glob_sort
# コマンドライン引数の --prefix=/usr とか=以降でも補完
setopt magic_equal_subst
# 無駄なスクロールを避ける
setopt always_last_prompt

setopt histignorealldups

add-zsh-hook precmd _update_vcs_info_msg

# %1vでpsvar[1]を呼び出したりしてる
PROMPT="%(?.%{${fg[green]}%}.%{${fg[red]}%})%n${reset_color}@${fg[blue]}%m${reset_color}(%*%) %F{green}%1v%f%F{yellow}%2v%f%F{red}%3v%f%~
%# "
