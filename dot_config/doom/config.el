;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq doom-theme 'doom-gruvbox)

(setq display-line-numbers-type 'relative)

;; The emoji module's +unicode flag picks the emoji set but leaves emojify
;; drawing images. Without downloaded images, the first buffer shown in a GUI
;; frame asks to download them, and the daemon blocks until someone answers.
;; Draw with the system emoji font instead.
(setq emojify-display-style 'unicode)

(setq org-directory "~/local-journal/org/")

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
