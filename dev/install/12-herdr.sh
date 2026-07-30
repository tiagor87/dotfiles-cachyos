#!/usr/bin/env bash
# 12-herdr.sh — herdr (multiplexador de terminal para agentes de código, TUI)
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# herdr-bin: binário pré-compilado das releases do upstream (sha256 pinado no
# PKGBUILD, sem dependências). O pacote `herdr` compila do fonte e precisa de
# cargo + zig0.15 — build longo, sem ganho aqui.
# A URL do PKGBUILD ainda aponta pro nome antigo do repo (ogulcancelik/herdr);
# o GitHub redireciona (301) pro oficial herdrdev/herdr, homepage herdr.dev.
aur_install herdr-bin

# Sem config versionado: os atalhos ficam nos DEFAULTS do herdr (prefix ctrl+b).
# Se um dia customizar, o arquivo é ~/.config/herdr/config.toml e o
# `herdr --default-config` imprime os defaults completos pra usar de base.
c_info "Uso:  herdr  (prefix ctrl+b · ctrl+b ? lista os atalhos · ctrl+b q desanexa)"
