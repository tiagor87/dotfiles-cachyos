#!/usr/bin/env bash
# 1-yay.sh — helper de AUR (yay) + base-devel/git para compilar pacotes do AUR
#
# Pré-requisito das demais categorias: vários pacotes (temas -git, *-bin,
# jetbrains-toolbox, docker-desktop, antigravity-cli, ttf-material-symbols…)
# só existem no AUR, e o pacman puro não os constrói. O aur_install() precisa
# de um helper (yay/paru). No CachyOS o yay vem no repo, então instalamos via
# pacman; base-devel e git são as dependências que o makepkg usa para compilar.
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# yay já cobre o AUR; base-devel + git dão suporte ao makepkg. Todos são
# pacotes reais dos repositórios (base-devel deixou de ser grupo), então
# repo_install reporta status/idempotência corretamente.
repo_install base-devel git yay
