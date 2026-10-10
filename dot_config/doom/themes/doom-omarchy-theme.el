;;; doom-omarchy-theme.el --- The current Omarchy theme -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Builds its palette from the theme `omarchy theme set' last applied, the way
;; Omarchy's generated Neovim theme does with aether.nvim, so every Omarchy
;; theme has an Emacs counterpart without a per-theme mapping. The palette is
;; read each time the theme loads: `load-theme' re-reads this file, and the
;; theme-set hook in ~/.config/omarchy/hooks/theme-set.d/emacs.sh asks the
;; daemon to do that after every switch.
;;
;; Colours come from `omarchy-theme-color --all' rather than colors.toml
;; directly: it fills in keys a theme leaves out (orange, brown, the derived
;; shades) the same way for every other consumer of the theme.

(require 'cl-lib)
(require 'doom-themes)

(defvar doom-omarchy--palette nil
  "The palette read when the theme last loaded, as an alist.")

(defvar doom-omarchy-colors-file
  (expand-file-name "~/.local/state/omarchy/current/theme/colors.toml")
  "The current Omarchy theme's palette.")

(defun doom-omarchy--program ()
  "Return the path of `omarchy-theme-color', or nil.
The Emacs daemon starts outside the Hyprland session, without Omarchy's bin
directory on its PATH, so fall back to where Omarchy installs it."
  (or (executable-find "omarchy-theme-color")
      (let ((path (expand-file-name
                   "bin/omarchy-theme-color"
                   (or (getenv "OMARCHY_PATH") "/usr/share/omarchy"))))
        (and (file-executable-p path) path))))

(defun doom-omarchy-available-p ()
  "Return non-nil when an Omarchy theme can be read."
  (and (file-readable-p doom-omarchy-colors-file)
       (doom-omarchy--program)
       t))

(defun doom-omarchy--read-colors ()
  "Return the current Omarchy palette as an alist of (KEY . VALUE) strings."
  (unless (doom-omarchy-available-p)
    (error "doom-omarchy: no Omarchy theme at %s" doom-omarchy-colors-file))
  (with-temp-buffer
    (unless (eq 0 (call-process (doom-omarchy--program) nil t nil
                                "--file" doom-omarchy-colors-file "--all"))
      (error "doom-omarchy: omarchy-theme-color failed: %s" (buffer-string)))
    (mapcar (lambda (line)
              (let ((fields (split-string line "\t")))
                (cons (car fields) (cadr fields))))
            (split-string (buffer-string) "\n" t))))

(defun doom-omarchy--luminance (hex)
  "Return the WCAG relative luminance of HEX."
  (apply #'+ (cl-mapcar
              (lambda (weight channel)
                (* weight (if (<= channel 0.03928)
                              (/ channel 12.92)
                            (expt (/ (+ channel 0.055) 1.055) 2.4))))
              '(0.2126 0.7152 0.0722)
              (doom-name-to-rgb hex))))

(defun doom-omarchy--contrast (a b)
  "Return the WCAG contrast ratio between hex colours A and B."
  (let ((la (doom-omarchy--luminance a))
        (lb (doom-omarchy--luminance b)))
    (/ (+ (max la lb) 0.05) (+ (min la lb) 0.05))))

(defun doom-omarchy--legible (color fg bg ratio)
  "Blend COLOR toward FG until it reaches contrast RATIO against BG.
Themes pick their dim foreground for a terminal's sparing use of it; a few
(White, for one) make it too faint to read as the colour of every comment."
  (let ((alpha 0.0) (result color))
    (while (and (< (doom-omarchy--contrast result bg) ratio) (< alpha 1.0))
      (setq alpha (min 1.0 (+ alpha 0.05))
            result (doom-blend fg color alpha)))
    result))

(let* ((c (doom-omarchy--read-colors))
       (get (lambda (key) (cdr (assoc key c))))
       (bg (funcall get "background"))
       (fg (funcall get "foreground")))
  (setq doom-omarchy--palette
        `((mode . ,(intern (funcall get "mode")))
          (bg . ,bg)
          (fg . ,fg)
          (bg-alt . ,(funcall get "dark_background"))
          (fg-alt . ,(doom-omarchy--legible (funcall get "dark_foreground") fg bg 3.0))
          (base0 . ,(funcall get "darker_background"))
          (base1 . ,(funcall get "dark_background"))
          (base2 . ,(doom-blend (funcall get "lighter_background") bg 0.5))
          (base3 . ,(funcall get "lighter_background"))
          (base4 . ,(doom-blend fg bg 0.25))
          (base5 . ,(doom-omarchy--legible (funcall get "dark_foreground") fg bg 3.0))
          (base6 . ,(doom-blend fg bg 0.6))
          (base7 . ,(doom-blend fg bg 0.8))
          (base8 . ,(funcall get "bright_foreground"))
          (red . ,(funcall get "red"))
          (orange . ,(funcall get "orange"))
          (green . ,(funcall get "green"))
          (teal . ,(funcall get "bright_cyan"))
          (yellow . ,(funcall get "yellow"))
          (blue . ,(funcall get "blue"))
          (magenta . ,(funcall get "magenta"))
          (violet . ,(funcall get "bright_magenta"))
          (cyan . ,(funcall get "cyan"))
          (accent . ,(funcall get "accent"))
          (cursor . ,(funcall get "cursor"))
          (selection . ,(funcall get "selection_background"))
          (muted . ,(funcall get "muted")))))

(defmacro doom-omarchy--color (key)
  "Return KEY from the palette in the (GUI 256-COLOR TTY) form Doom expects.
Emacs approximates the hex colour on a terminal without truecolor."
  `(let ((value (cdr (assq ',key doom-omarchy--palette))))
     (if (stringp value) (list value value nil) value)))

(def-doom-theme doom-omarchy
  "The theme `omarchy theme set' last applied."
  :family 'doom-omarchy
  :background-mode (doom-omarchy--color mode)

  ((bg         (doom-omarchy--color bg))
   (fg         (doom-omarchy--color fg))
   (bg-alt     (doom-omarchy--color bg-alt))
   (fg-alt     (doom-omarchy--color fg-alt))

   (base0      (doom-omarchy--color base0))
   (base1      (doom-omarchy--color base1))
   (base2      (doom-omarchy--color base2))
   (base3      (doom-omarchy--color base3))
   (base4      (doom-omarchy--color base4))
   (base5      (doom-omarchy--color base5))
   (base6      (doom-omarchy--color base6))
   (base7      (doom-omarchy--color base7))
   (base8      (doom-omarchy--color base8))

   (grey       base4)
   (red        (doom-omarchy--color red))
   (orange     (doom-omarchy--color orange))
   (green      (doom-omarchy--color green))
   (teal       (doom-omarchy--color teal))
   (yellow     (doom-omarchy--color yellow))
   (blue       (doom-omarchy--color blue))
   (dark-blue  (doom-blend blue bg 0.5))
   (magenta    (doom-omarchy--color magenta))
   (violet     (doom-omarchy--color violet))
   (cyan       (doom-omarchy--color cyan))
   (dark-cyan  (doom-blend cyan bg 0.7))

   (highlight      (doom-omarchy--color accent))
   (cursor-bg      (doom-omarchy--color cursor))
   (vertical-bar   base0)
   (selection      (doom-omarchy--color selection))
   (builtin        magenta)
   (comments       base5)
   (doc-comments   (doom-blend fg base5 0.25))
   (constants      violet)
   (functions      magenta)
   (keywords       blue)
   (methods        cyan)
   (operators      blue)
   (type           yellow)
   (strings        green)
   (variables      (doom-blend magenta fg 0.4))
   (numbers        orange)
   (region         (doom-omarchy--color selection))
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    orange)
   (vc-added       green)
   (vc-deleted     red)

   (modeline-fg          fg)
   (modeline-fg-alt      base5)
   (modeline-bg          bg-alt)
   (modeline-bg-inactive bg))

  ((cursor :background cursor-bg)
   ((line-number &override) :foreground base4)
   ((line-number-current-line &override) :foreground fg)
   (mode-line :background modeline-bg :foreground modeline-fg)
   (mode-line-inactive :background modeline-bg-inactive :foreground modeline-fg-alt)
   (mode-line-emphasis :foreground highlight)
   (doom-modeline-bar :background highlight)
   (doom-modeline-buffer-file :inherit 'mode-line-buffer-id :weight 'bold)
   (doom-modeline-buffer-path :inherit 'mode-line-emphasis :weight 'bold)
   (doom-modeline-buffer-project-root :foreground green :weight 'bold)
   (markdown-markup-face :foreground base5)
   (markdown-header-face :inherit 'bold :foreground highlight)
   ((markdown-code-face &override) :background base1)
   (solaire-mode-line-face :inherit 'mode-line :background modeline-bg)
   (solaire-mode-line-inactive-face :inherit 'mode-line-inactive :background modeline-bg-inactive)))

;;; doom-omarchy-theme.el ends here
