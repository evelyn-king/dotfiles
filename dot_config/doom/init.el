;;; init.el -*- lexical-binding: t; -*-

(doom! :input

       :completion
       (corfu +orderless)  ; in-buffer completion with orderless matching
       vertico

       :ui
       doom
       dashboard
       doom-quit
       (emoji +unicode)
       hl-todo
       modeline
       ophints
       (popup +defaults)
       (vc-gutter +pretty)
       vi-tilde-fringe
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       snippets
       (whitespace +guess +trim)

       :emacs
       dired
       electric
       tramp
       undo
       vc

       :term
       vterm

       :checkers
       syntax
       (spell +flyspell)

       :tools
       debugger
       direnv
       ein
       (eval +overlay)
       lookup
       magit
       pdf
       tmux
       tree-sitter

       :os
       (:if (featurep :system 'macos) macos)

       :lang
       data
       emacs-lisp
       json
       javascript
       lua
       markdown
       org
       python
       sh
       yaml

       :config
       (default +bindings +smartparens))
