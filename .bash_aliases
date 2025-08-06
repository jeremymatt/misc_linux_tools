alias tm='tmux new-session -A -s'

git_acp() {
        git add -A
        git commit -m "$1"
        git push
}

alias short_prompt="export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '"
alias long_prompt="export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '"

alias mount_drives="sudo mount -t drvfs V: /mnt/datanas && sudo mount -t drvfs Z: /mnt/z"
alias goto_3d="cd /mnt/c/local_working/EOD_Datahub/eod3D_pipeline"
alias goto_cs="cd /mnt/c/local_working/EOD_Datahub/circuit_sense/github/circuit-sense"






