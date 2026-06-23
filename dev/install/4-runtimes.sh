#!/usr/bin/env bash
# 4-runtimes.sh — Runtimes de linguagem: Node.js + .NET
set -uo pipefail
source "${DOTFILES_ROOT:?}/lib/install-helpers.sh"

# Node.js + npm e o .NET SDK (+ ASP.NET runtime, p/ apps web .NET). Repo oficial.
repo_install nodejs npm dotnet-sdk aspnet-runtime
