;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; doom-themes has no Rosé Pine, so use the community port.
(package! doom-rose-pine-theme
  :recipe (:host github :repo "donniebreve/rose-pine-doom-emacs"
           :files ("*.el"))
  :pin "78100823087f2fa727cdd5c06f8deb17988520b6")
