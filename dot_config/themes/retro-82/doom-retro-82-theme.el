;;; doom-retro-82-theme.el --- A dark retro theme with deep navy and warm amber -*- no-byte-compile: t; -*-

(require 'doom-themes)

(defgroup doom-retro-82-theme nil
  "Options for the doom-retro-82 theme."
  :group 'doom-themes)

(def-doom-theme doom-retro-82
  "A retro terminal theme: deep navy background, warm amber foreground, orange and teal accents."

  ;; name         default    256        16
  ((bg           '("#05182e" "black"    "black"        ))
   (fg           '("#f6dcac" "#bfbfbf"  "brightwhite"  ))

   (bg-alt       '("#00172e" "black"    "black"        ))
   (fg-alt       '("#a7c9c6" "#dfdfdf"  "white"        ))

   (base0        '("#00172e" "black"    "black"        ))
   (base1        '("#04213d" "#1e1e1e"  "brightblack"  ))
   (base2        '("#082d50" "#2e2e2e"  "brightblack"  ))
   (base3        '("#0d3a63" "#262626"  "brightblack"  ))
   (base4        '("#134e5a" "#3f3f3f"  "brightblack"  ))
   (base5        '("#1a6070" "#525252"  "brightblack"  ))
   (base6        '("#3f8f8a" "#6b6b6b"  "brightblack"  ))
   (base7        '("#8cbfb8" "#979797"  "brightblack"  ))
   (base8        '("#a7c9c6" "#dfdfdf"  "white"        ))

   (grey         base4)
   (red          '("#f85525" "#ff6655"  "red"          ))
   (orange       '("#e97b3c" "#dd8844"  "brightred"    ))
   (green        '("#028391" "#00afaf"  "green"        ))
   (teal         '("#3f8f8a" "#44b9b1"  "brightgreen"  ))
   (yellow       '("#faa968" "#ffaf5f"  "yellow"       ))
   (blue         '("#028391" "#00afaf"  "brightblue"   ))
   (dark-blue    '("#134e5a" "#005f5f"  "blue"         ))
   (magenta      '("#8cbfb8" "#87d7d7"  "brightmagenta"))
   (violet       '("#faa968" "#ffaf5f"  "magenta"      ))
   (cyan         '("#8cbfb8" "#87d7d7"  "brightcyan"   ))
   (dark-cyan    '("#3f8f8a" "#44b9b1"  "cyan"         ))

   ;; semantic colors
   (highlight      yellow)
   (vertical-bar   bg-alt)
   (selection      dark-blue)
   (builtin        teal)
   (comments       base5)
   (doc-comments   base6)
   (constants      yellow)
   (functions      teal)
   (keywords       orange)
   (methods        cyan)
   (operators      fg)
   (type           yellow)
   (strings        green)
   (variables      fg)
   (numbers        yellow)
   (region         `(,(doom-lighten (car bg-alt) 0.1) ,@(cdr bg-alt)))
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    orange)
   (vc-added       green)
   (vc-deleted     red)

   (modeline-fg              fg)
   (modeline-fg-alt          base5)
   (modeline-bg              `(,(doom-darken (car bg) 0.2) ,@(cdr bg)))
   (modeline-bg-alt          `(,(doom-darken (car bg) 0.15) ,@(cdr bg)))
   (modeline-bg-inactive     `(,(doom-darken (car bg-alt) 0.1) ,@(cdr bg-alt)))
   (modeline-bg-alt-inactive `(,(doom-darken (car bg-alt) 0.05) ,@(cdr bg-alt))))

  ;; face overrides
  ((doom-modeline-bar         :background yellow)
   (doom-modeline-bar-inactive :background vertical-bar)
   (cursor                    :background yellow)
   (hl-line                   :background base1)))
