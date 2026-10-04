;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq doom-theme 'doom-gruvbox)

(setq display-line-numbers-type 'relative)

;; The emoji module's +unicode flag picks the emoji set but leaves emojify
;; drawing images. Without downloaded images, the first buffer shown in a GUI
;; frame asks to download them, and the daemon blocks until someone answers.
;; Draw with the system emoji font instead.
(setq emojify-display-style 'unicode)

;; The Emacs daemon does not change its environment when a shell enters a
;; project. Read mise's resolved environment before Doom starts its Python LSP.
(defun +project-mise-env-h ()
  "Use the current project's mise environment in this file buffer."
  (when (and buffer-file-name
             (not (file-remote-p default-directory))
             (executable-find "mise"))
    (let* ((directory default-directory)
           (mise (executable-find "mise"))
           (env (with-temp-buffer
                  (let ((default-directory directory))
                    (if (eq 0 (call-process mise nil t nil "env" "--json"))
                        (progn (goto-char (point-min))
                               (json-parse-buffer))
                      (message "mise env failed for %s" directory)
                      nil)))))
      (when env
        (setq-local process-environment (copy-sequence process-environment))
        (maphash (lambda (name value) (setenv name value)) env)
        (when-let ((path (getenv "PATH")))
          (setq-local exec-path (parse-colon-path path)))))))
(add-hook 'hack-local-variables-hook #'+project-mise-env-h -90)

(after! python
  ;; mise puts the active uv or micromamba Python first on the buffer's PATH.
  (add-hook! '(python-mode-local-vars-hook python-ts-mode-local-vars-hook)
    (defun +python-use-project-interpreter-h ()
      (when (or (getenv "VIRTUAL_ENV") (getenv "CONDA_PREFIX"))
        (when-let ((python (executable-find "python")))
          (setq-local python-shell-interpreter python)))))
  (set-eglot-client! '(python-mode python-ts-mode) '("ty" "server"))
  (set-formatter! 'ruff :modes '(python-mode python-ts-mode)))

;; Roughly 2.5x wide and 2x tall compared to Emacs's 80x36 default.
(add-to-list 'default-frame-alist '(width . 200))
(add-to-list 'default-frame-alist '(height . 72))

;; `org-agenda-files' is set by the GTD section below.
(setq org-directory "~/local-journal/org/"
      org-roam-directory org-directory
      org-roam-dailies-directory "journal/"
      ;; %[...] inserts templates/daily.org only when the day's file is created.
      org-roam-dailies-capture-templates
      `(("d" "default" entry "* %?"
         :target (file+head "%<%Y-%m-%d>.org"
                            ,(format "%%[%s]" (expand-file-name "templates/daily.org" doom-user-dir))))))

;; org-download pastes clipboard images with wl-paste only when
;; XDG_SESSION_TYPE says wayland, and wl-paste needs WAYLAND_DISPLAY. systemd
;; can start the daemon before Hyprland exports either, so take them from the
;; PGTK frame doing the paste instead.
(defadvice! +org-download-clipboard-wayland-a (fn &rest args)
  :around #'org-download-clipboard
  (let ((display (frame-parameter nil 'display)))
    (if (and (featurep 'pgtk) (stringp display))
        (let ((process-environment
               (append (list "XDG_SESSION_TYPE=wayland"
                             (concat "WAYLAND_DISPLAY=" display))
                       process-environment)))
          (apply fn args))
      (apply fn args))))

;; org-roam-capture, then "p": a person note with contact properties.
;; EMAIL holds one or more space-separated addresses (quote any with spaces).
(after! org-roam
  (add-to-list 'org-roam-capture-templates
               '("p" "person" plain "%?"
                 :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                                    ":PROPERTIES:\n:EMAIL: \n:COMPANY: \n:END:\n#+title: ${title}\n#+filetags: :person:\n")
                 :unnarrowed t)
               t))

;; Consistency check for person notes; run with M-x +people-check.
;; Run M-x org-roam-db-sync first, since this reads the roam DB, not the files.
(defun +people-check ()
  "Report org-roam notes tagged `person' that have bad contact metadata.

A person note is any node with the \"person\" filetag (see the \"p\"
capture template).  Each must have a non-empty COMPANY property and an
EMAIL property holding one or more space-separated, well-formed addresses.

Problems are listed one per line in the *people-check* buffer; if there
are none, a message says so.  Reads the org-roam DB, so unsynced edits
are not seen."
  (interactive)
  (let (problems)
    (dolist (node (org-roam-node-list))
      (when (member "person" (org-roam-node-tags node))
        (let* ((props (org-roam-node-properties node))
               (emails (split-string (or (cdr (assoc "EMAIL" props)) "")))
               (company (cdr (assoc "COMPANY" props))))
          (cond ((null emails)
                 (push (format "%s: no EMAIL" (org-roam-node-title node)) problems))
                ((cl-notevery (lambda (e) (string-match-p "\\`[^@ ]+@[^@ ]+\\.[^@ ]+\\'" e))
                              emails)
                 (push (format "%s: malformed EMAIL" (org-roam-node-title node)) problems)))
          (unless (and company (not (string-empty-p company)))
            (push (format "%s: no COMPANY" (org-roam-node-title node)) problems)))))
    (if problems
        (with-current-buffer (get-buffer-create "*people-check*")
          (erase-buffer)
          (insert (string-join (nreverse problems) "\n") "\n")
          (pop-to-buffer (current-buffer)))
      (message "All person notes look fine."))))

;;; GTD
;; Tasks live in the roam nodes they belong to, and the agenda collects them.
;; Projects are nodes tagged :project: (org-roam-capture, then "P"); when one
;; is finished, swap that tag for :done:.  Quick captures (SPC X i) and open
;; tasks swept out of the dailies land in the gtd-inbox node.  Everything in
;; the gtd-someday node inherits its :someday: tag, which keeps it out of the
;; Engage view until the weekly review.  Agenda dispatcher: "g" is Engage,
;; "w" is the weekly review.

(defconst +gtd--open-task-re "^\\*+ (TODO|NEXT|WAIT) "
  "Ripgrep pattern matching a heading with an open task keyword.")

(defun +gtd--node-file (name &optional filetags)
  "Return the path of the roam node file NAME.org, creating it if missing.
A new file gets an ID, the title NAME and, if given, FILETAGS."
  (let ((file (expand-file-name (concat name ".org") org-roam-directory)))
    (unless (file-exists-p file)
      (require 'org-id)
      (with-temp-file file
        (insert ":PROPERTIES:\n:ID:       " (org-id-new) "\n:END:\n"
                "#+title: " name "\n"
                (if filetags (format "#+filetags: %s\n" filetags) "")))
      (when (fboundp 'org-roam-db-update-file)
        (org-roam-db-update-file file)))
    file))

(defun +gtd-inbox-file () (+gtd--node-file "gtd-inbox"))
(defun +gtd-someday-file () (+gtd--node-file "gtd-someday" ":someday:"))

(defun +gtd--rg (dir &rest patterns)
  "Return the .org files under DIR matching any of PATTERNS (ripgrep syntax)."
  (let ((default-directory dir))
    (mapcar #'expand-file-name
            (apply #'process-lines-ignore-status
                   "rg" "--files-with-matches" "--glob" "*.org"
                   (append (mapcan (lambda (p) (list "-e" p)) patterns) '("."))))))

(defun +gtd-update-agenda-files ()
  "Point `org-agenda-files' at the roam files with open tasks or a :project: tag.
Recomputed on every agenda run, so new notes are picked up without a restart."
  (+gtd-someday-file)
  (setq org-agenda-files
        (+gtd--rg org-roam-directory +gtd--open-task-re
                  "^#\\+(?i:filetags):.*:project:")))

(defun +gtd-sweep-dailies ()
  "Move open tasks out of the daily notes and into gtd-inbox.
Each task's subtree is appended to the inbox with a link back to its daily.
The daily keeps a list item linking to the task where it now lives."
  (interactive)
  (let ((dailies (expand-file-name org-roam-dailies-directory org-roam-directory))
        moved)
    (dolist (file (+gtd--rg dailies +gtd--open-task-re))
      (let* ((visiting (find-buffer-visiting file))
             (buf (or visiting (find-file-noselect file))))
        (with-current-buffer buf
          (org-with-wide-buffer
           (let ((daily (org-link-make-string
                         (concat "id:" (org-with-point-at 1 (org-id-get-create)))
                         (org-get-title))))
             (goto-char (point-min))
             (while (re-search-forward org-not-done-heading-regexp nil t)
               (org-back-to-heading t)
               (let ((beg (point))
                     (id (org-id-get-create))
                     (heading (org-get-heading t t t t)))
                 (org-end-of-meta-data)
                 (unless (bolp) (insert "\n"))
                 (insert "From " daily "\n")
                 (goto-char beg)
                 (let ((end (save-excursion (org-end-of-subtree t t))))
                   (push (cons id (buffer-substring beg end)) moved)
                   (delete-region beg end))
                 (insert "- Moved to gtd-inbox: "
                         (org-link-make-string (concat "id:" id) heading) "\n")))))
          (save-buffer))
        (unless visiting (kill-buffer buf))))
    (when moved
      (let ((inbox (+gtd-inbox-file)))
        (with-current-buffer (find-file-noselect inbox)
          (org-with-wide-buffer
           (dolist (task (reverse moved))
             (goto-char (point-max))
             (unless (bolp) (insert "\n"))
             (org-paste-subtree 1 (cdr task))
             (org-id-add-location (car task) inbox)))
          (save-buffer))))
    (when (or moved (called-interactively-p 'interactive))
      (message "Moved %d task(s) to gtd-inbox" (length moved)))))

(defun +gtd-agenda-refresh-a (&rest _)
  "Sweep the dailies and recompute the agenda files before an agenda run."
  (+gtd-sweep-dailies)
  (+gtd-update-agenda-files))
(advice-add #'org-agenda :before #'+gtd-agenda-refresh-a)
(advice-add #'org-agenda-redo-all :before #'+gtd-agenda-refresh-a)

(defun +gtd--agenda-title ()
  "Return the title of the agenda entry's node, trimmed to fit the prefix column."
  (truncate-string-to-width (or (org-get-title) (org-get-category) "") 24 nil nil "…"))

(defun +gtd--skip-someday ()
  "Agenda skip function: skip entries tagged, or inheriting, :someday:."
  (when (member "someday" (org-get-tags))
    (save-excursion (or (outline-next-heading) (point-max)))))

(defun +gtd--skip-unless-stuck ()
  "Agenda skip function: skip a project's Tasks heading if it has a NEXT under it."
  (let ((end (save-excursion (org-end-of-subtree t))))
    (when (save-excursion (re-search-forward "^\\*+ NEXT " end t))
      end)))

(after! org
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAIT(w)" "|" "DONE(d)" "CANCELLED(c)"))
        org-todo-keyword-faces
        '(("NEXT" . +org-todo-active)
          ("WAIT" . +org-todo-onhold)
          ("CANCELLED" . +org-todo-cancel))
        ;; The node title in the prefix already says which project it is.
        org-agenda-hide-tags-regexp "\\`project\\'"
        org-agenda-prefix-format
        '((agenda . " %i %-25(+gtd--agenda-title)%?-12t% s")
          (todo . " %i %-25(+gtd--agenda-title)")
          (tags . " %i %-25(+gtd--agenda-title)")
          (search . " %i %-25(+gtd--agenda-title)"))
        org-agenda-custom-commands
        '(("g" "GTD: engage"
           ((agenda "" ((org-agenda-span 'day)
                        (org-agenda-skip-function #'+gtd--skip-someday)))
            (todo "NEXT" ((org-agenda-overriding-header "Next actions")
                          (org-agenda-skip-function #'+gtd--skip-someday)))
            (todo "WAIT" ((org-agenda-overriding-header "Waiting on")
                          (org-agenda-skip-function #'+gtd--skip-someday)))))
          ("w" "GTD: weekly review"
           ((alltodo "" ((org-agenda-overriding-header "Inbox")
                         (org-agenda-files (list (+gtd-inbox-file)))))
            ;; Relies on the "* Tasks" heading from the project template.
            (tags "+project-someday+LEVEL=1+ITEM=\"Tasks\""
                  ((org-agenda-overriding-header "Stuck projects (no NEXT)")
                   (org-agenda-skip-function #'+gtd--skip-unless-stuck)))
            (todo "WAIT" ((org-agenda-overriding-header "Waiting on")))
            (tags-todo "someday" ((org-agenda-overriding-header "Someday/maybe")))))))
  (+gtd-update-agenda-files))

(defun +gtd--capture-source-link ()
  "Return a \"From [[id:...]]\" line for the roam node the capture started in.
From the agenda, the node is the one holding the item at point.  Outside a
roam node, fall back to `org-store-link''s link, or nothing."
  (let* ((buf (org-capture-get :original-buffer))
         (node (when (and (buffer-live-p buf) (fboundp 'org-roam-node-at-point))
                 (with-current-buffer buf
                   (let ((marker (and (derived-mode-p 'org-agenda-mode)
                                      (or (org-get-at-bol 'org-hd-marker)
                                          (org-get-at-bol 'org-marker)))))
                     (cond (marker (org-with-point-at marker (org-roam-node-at-point)))
                           ((derived-mode-p 'org-mode) (org-roam-node-at-point)))))))
         (link (if node
                   (org-link-make-string (concat "id:" (org-roam-node-id node))
                                         (org-roam-node-title node))
                 (org-capture-get :annotation))))
    (if (org-string-nw-p link) (concat "From " link) "")))

(after! org-capture
  (add-to-list 'org-capture-templates
               '("i" "GTD inbox" entry (file +gtd-inbox-file)
                 "* TODO %?\n:PROPERTIES:\n:CREATED:  %U\n:END:\n%(+gtd--capture-source-link)")
               t))

(after! org-roam
  ;; Tasks get IDs when swept from the dailies; keep them out of node-find.
  (setq org-roam-db-node-include-function
        (lambda ()
          (not (save-excursion
                 (and (ignore-errors (org-back-to-heading t)) (org-get-todo-state))))))
  (add-to-list 'org-roam-capture-templates
               '("P" "project" plain "Outcome: %?\n\n* Tasks\n* Notes\n"
                 :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                                    "#+title: ${title}\n#+filetags: :project:\n")
                 :unnarrowed t)
               t))

(add-to-list '+dashboard-menu-sections
             '("Open today's note"
               :icon (nerd-icons-octicon "nf-oct-note" :face '+dashboard-menu-title)
               :when (fboundp 'org-roam-dailies-goto-today)
               :action org-roam-dailies-goto-today))

(add-to-list '+dashboard-menu-sections
             '("Find roam note"
               :icon (nerd-icons-octicon "nf-oct-database" :face '+dashboard-menu-title)
               :action org-roam-node-find)
             t)

(defun my/dashboard-banner ()
  "A small banner in place of Doom's full-size logo."
  (propertize
   (string-join
    '("    _"
      " __| |___  ___ _ __"
      "/ _` / _ \\/ _ \\ '  \\"
      "\\__,_\\___/\\___/_|_|_|")
    "\n")
   'face '+dashboard-banner))

(setq +dashboard-ascii-banner-fn #'my/dashboard-banner)

;; Discovery checks exactly DEPTH levels down, and repos here sit at both two
;; and three levels (org/repo and org/group/repo), so search both.
(setq projectile-project-search-path
      '(("~/local-projects/codes" . 2)
        ("~/local-projects/codes" . 3)))

;; Drop projects whose directory is gone, such as removed worktrees.
(setq projectile-auto-cleanup-known-projects t)

;;; Worktrees

(defun my/worktree-repo (root)
  "Return the repo directory ROOT is a linked worktree of, or nil.
For a bare clone at REPO/.git that is REPO, the directory holding its worktrees."
  (let ((dotgit (expand-file-name ".git" root)))
    (when (file-regular-p dotgit)
      (with-temp-buffer
        (insert-file-contents dotgit)
        (when (re-search-forward "^gitdir: \\(.+?\\)/\\.git/worktrees/[^/\n]+$" nil t)
          (file-name-as-directory (expand-file-name (match-string 1) root)))))))

(defun my/worktree-label (root repo)
  "Name worktree ROOT of REPO without the <repo>. prefix of sibling worktrees."
  (let ((repo-name (file-name-nondirectory (directory-file-name repo))))
    (string-remove-prefix (concat repo-name ".")
                          (file-name-nondirectory (directory-file-name root)))))

(defun my/project-name (root)
  "Name worktrees REPO:WORKTREE so every repo's main worktree isn't just main."
  (if-let* ((repo (my/worktree-repo root)))
      (format "%s:%s"
              (file-name-nondirectory (directory-file-name repo))
              (my/worktree-label root repo))
    (projectile-default-project-name root)))

(setq projectile-project-name-function #'my/project-name)

(defun my/bare-repo-container-p (dir)
  "Non-nil if DIR holds a bare clone at DIR/.git rather than a checkout."
  (let ((config (expand-file-name ".git/config" dir)))
    (and (file-regular-p config)
         (with-temp-buffer
           (insert-file-contents config)
           (re-search-forward "^[ \t]*bare[ \t]*=[ \t]*true" nil t)))))

;; The folder around a bare clone looks like a project to projectile, but it has
;; no checkout of its own; its worktrees are the projects.
(after! projectile
  (add-function :before-until projectile-ignored-project-function
                #'my/bare-repo-container-p))

(defun my/wt--branches ()
  "Return (BRANCH . WORKTREE-OR-NIL) for the repo at `default-directory'."
  (with-temp-buffer
    (unless (zerop (process-file "wt" nil '(t nil) nil
                                 "list" "--format=json" "--branches"))
      (user-error "wt list failed in %s" default-directory))
    (goto-char (point-min))
    (let ((json (json-parse-buffer :object-type 'alist :array-type 'list
                                   :null-object nil :false-object nil)))
      (delq nil
            (mapcar (lambda (item)
                      (when-let* ((branch (alist-get 'branch item)))
                        (cons branch (alist-get 'path (alist-get 'worktree item)))))
                    (alist-get 'items json))))))

(defun my/wt-switch (branch)
  "Open the worktree for BRANCH, creating it with worktrunk if needed.
A name that isn't an existing branch creates one. worktrunk runs in a comint
buffer so its hook approval prompts can be answered there."
  (interactive
   (let ((default-directory (or (doom-project-root) default-directory)))
     (list (completing-read "Worktree (a new name creates the branch): "
                            (my/wt--branches)))))
  (let* ((default-directory (or (doom-project-root) default-directory))
         (known (assoc branch (my/wt--branches))))
    (if (cdr known)
        (projectile-switch-project-by-name (cdr known))
      (with-current-buffer
          (compilation-start
           (mapconcat #'shell-quote-argument
                      `("wt" "switch" ,@(unless known '("--create")) ,branch "--no-cd")
                      " ")
           t (lambda (_) "*wt*"))
        (add-hook 'compilation-finish-functions
                  (lambda (_buf status)
                    (when (string-prefix-p "finished" status)
                      (when-let* ((path (cdr (assoc branch (my/wt--branches)))))
                        (projectile-switch-project-by-name path))))
                  nil t)))))

(map! :leader :desc "Switch/create worktree" "p w" #'my/wt-switch)

;;; Dashboard projects

(defvar my/dashboard-repo-count 8
  "How many repos to list on the dashboard.")

(defun my/dashboard--project-groups ()
  "Known projects as (REPO ROOT...), most recently used first.
A worktree is grouped under the repo it belongs to."
  (let (groups)
    (dolist (root (projectile-known-projects))
      (let* ((root (file-name-as-directory (expand-file-name root)))
             (key (or (my/worktree-repo root) root))
             (group (assoc key groups)))
        (unless group
          (setq group (list key))
          (push group groups))
        (setcdr group (append (cdr group) (list root)))))
    (nreverse groups)))

(defun my/dashboard--button (label root)
  (with-temp-buffer
    (insert-text-button label
                        'action (lambda (_) (projectile-switch-project-by-name root))
                        'face '+dashboard-menu-title
                        'follow-link t
                        'help-echo (format "Switch to %s" (abbreviate-file-name root)))
    (buffer-string)))

(defun my/dashboard-widget-projects ()
  "List known projects, with each repo's worktrees indented beneath it."
  (when-let* (((require 'projectile nil t))
              (groups (seq-take (my/dashboard--project-groups)
                                my/dashboard-repo-count)))
    (insert "\n")
    (apply #'+dashboard-insert
           (propertize "Projects" 'face '+dashboard-menu-desc)
           (mapcan
            (lambda (group)
              (let* ((repo (car group))
                     (name (file-name-nondirectory (directory-file-name repo)))
                     (worktrees (remove repo (cdr group))))
                (cons
                 ;; A bare clone's folder is not a project, so its name is a
                 ;; plain heading rather than a button.
                 (if (member repo (cdr group))
                     (my/dashboard--button name repo)
                   (propertize name 'face '+dashboard-menu-desc))
                 (mapcar (lambda (root)
                           (concat "  "
                                   (nerd-icons-octicon "nf-oct-git_branch"
                                                       :face '+dashboard-menu-desc)
                                   " "
                                   (my/dashboard--button (my/worktree-label root repo)
                                                         root)))
                         worktrees))))
            groups))))

(setq +dashboard-functions
      '(+dashboard-widget-banner
        +dashboard-widget-shortmenu
        my/dashboard-widget-projects
        +dashboard-widget-footer
        +dashboard-widget-loaded))

;; M-x org-roam-ui-mode serves the graph at http://localhost:35901.
(use-package! org-roam-ui
  :after org-roam
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t)
  ;; `org-roam-ui-sync-theme' only picks the colours; nothing sends them to the
  ;; browser unless the command is run, so push them on connect and theme change.
  (defun +org-roam-ui-sync-theme-h (&rest _)
    (when (and (bound-and-true-p org-roam-ui-ws-socket)
               (websocket-openp org-roam-ui-ws-socket))
      (org-roam-ui-sync-theme)))
  (advice-add #'org-roam-ui--ws-on-open :after #'+org-roam-ui-sync-theme-h)
  (add-hook 'doom-load-theme-hook #'+org-roam-ui-sync-theme-h))
