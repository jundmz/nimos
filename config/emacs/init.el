;;; init.el --- basic Emacs config  -*- lexical-binding: t; -*-
;; Live-editable: changes take effect on next Emacs start (no nixos-rebuild needed).
;; Nix-managed packages (which-key) are on the load-path via the emacs wrapper.

;; ── Startup ────────────────────────────────────────────────────────────────────
(setq inhibit-startup-message t
      ring-bell-function      'ignore)

;; ── UI chrome ──────────────────────────────────────────────────────────────────
(menu-bar-mode -1)
(when (display-graphic-p)
  (tool-bar-mode   -1)
  (scroll-bar-mode -1)
  (set-frame-font "JetBrains Mono 13" nil t))

;; ── Editing defaults ───────────────────────────────────────────────────────────
(setq-default indent-tabs-mode nil
              tab-width         2)
(electric-pair-mode 1)
(show-paren-mode    1)

;; ── Line numbers (relative, like Helix) ───────────────────────────────────────
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)

;; ── Theme: modus-vivendi (dark, built-in since Emacs 28) ──────────────────────
(load-theme 'modus-vivendi t)

;; ── Packages ───────────────────────────────────────────────────────────────────
(require 'package)
(package-initialize)

;; which-key — Nix-managed, just configure it
(use-package which-key
  :config (which-key-mode))

;; helix-mode — fetched from GitHub on first run (Emacs 29+ :vc support)
;; Saved to ~/.emacs.d/elpa/ and reused on subsequent starts.
(use-package helix
  :vc (:url "https://github.com/mgmarlow/helix-mode")
  :config (helix-mode))
