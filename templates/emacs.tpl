;; Keep version controlled backups
(setq
   backup-by-copying t      ; don't clobber symlinks
   delete-old-versions t
   kept-new-versions 10
   kept-old-versions 1
   version-control t
   vc-make-backup-files t
   backup-directory-alist '(("" . "~/.emacs.old/backup/per-save")))

(defun force-backup-of-buffer ()
  ;; Make a special "per session" backup at the first save of each
  ;; emacs session.
  (when (not buffer-backed-up)
    ;; Override the default parameters for per-session backups.
    (let ((backup-directory-alist '(("" . "~/.emacs.old/backup/per-session")))

	  (kept-new-versions 3))
      (backup-buffer)))
  ;; Make a "per save" backup on each save.  The first save results in
  ;; both a per-session and a per-save backup, to keep the numbering
  ;; of per-save backups consistent.
  (let ((buffer-backed-up nil))
    (backup-buffer)))

(add-hook 'before-save-hook  'force-backup-of-buffer)
