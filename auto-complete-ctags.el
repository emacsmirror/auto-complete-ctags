;;; auto-complete-ctags.el ---

;; Copyright (C) 2011  whitypig

;; Author: whitypig <whitypig@gmail.com>
;; Keywords: auto-complete-mode, ctags

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'auto-complete)
(eval-when-compile
  (require 'cl))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Customize ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup auto-complete-ctags nil
  "A source for auto-complete-mode usign Exuberant ctags."
  :prefix "ac-ctags-"
  :group 'convenience)

(defcustom ac-ctags-candidate-limit 50
  "The upper limit number of candidates to be shown."
  :type 'number
  :group 'auto-complete-ctags)

(defcustom ac-ctags-mode-to-string-table
  '((c-mode ("C"))
    (c++-mode ("C++" "C"))
    (java-mode ("Java"))
    (jde-mode ("Java"))
    (malabar-mode ("Java"))
    (php-mode ("PHP")))
  "A table for mapping major-mode to its representing string."
  :type 'list
  :group 'auto-complete-ctags)

(defcustom ac-ctags-vector-default-size 1023
  "The default size of vector used as completion table"
  :type 'number
  :group 'auto-complete-ctags)

(defface ac-ctags-candidate-face
  '((t (:background "slate gray" :foreground "white")))
  "Face for ctags candidate")

(defface ac-ctags-selection-face
  '((t (:background "PaleGreen4" :foreground "white")))
  "Face for the ctags selected candidate.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Variables ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar ac-ctags-current-tags-list nil
  "Current list of tags.")

(defvar ac-ctags-tags-list-set nil
  "The set of lists of tags files.")

(defvar ac-ctags-tags-db nil
  "An association list with keys being languages and values being
the information extracted from tags file created by ctags
program. The following is an example:
`((\"C++\" (name command signature)...)
  (\"C\" (name command signature)...)
  (\"Java\" (name command signature)...)
  (\"Others\" (name command signature)...)'")

(defvar ac-ctags-completion-table nil
  "An association list with keys being a language and values being a
vector containing tag names in tags files. The following is an
example.
`((\"C++\" . [name1 name2 name3...])
  (\"Java\" . [name1 name2 name3...])
  (\"Others\" . [name1 name2 name3)])'")

(defvar ac-ctags-current-completion-table nil
  "A vector used for completion for `ac-ctags-current-tags-list'.")

(defvar ac-ctags-prefix-funtion-table
  '((c++-mode . ac-ctags-c++-prefix))
  "A table of prefix functions for a specific major mode.")

(defvar ac-ctags-document-function-table
  '((c++-mode . ac-ctags-c++-document))
  "A table of document functions")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ac-ctags-visit-tags-file (file &optional new)
  "Visit tags file."
  (interactive (list (expand-file-name
                      (read-file-name "Visit tags file (default tags): "
                                      nil
                                      "tags"
                                      t))))
  (or (stringp file) (signal 'wrong-type-argument (list 'stringp file)))
  (let ((tagsfile file))
    (unless (ac-ctags-is-valid-tags-file-p tagsfile)
      (error "Invalid tags: %s is not a valid tags file" tagsfile))
    (ac-ctags-build tagsfile new)
    (message "Current tags list: %s" ac-ctags-current-tags-list)))

(defun ac-ctags-update-tags-list (tagsfile new)
  "Update `ac-ctags-current-tags-list' and`ac-ctags-tags-list-set' if
need be."
  (cond
   ((null ac-ctags-current-tags-list)
    (ac-ctags-insert-tags-into-current-list tagsfile))
   ;; Ask user whether the tags will be inserted into the current
   ;; list or a new one, and do insert.
   ((or (eq new 'new)
        (and (not (eq new 'current))
             (ac-ctags-create-new-list-p tagsfile)))
    (ac-ctags-insert-tags-into-new-list tagsfile))
   (t
    (ac-ctags-insert-tags-into-current-list tagsfile))))

;; todo use progress reporter
(defun ac-ctags-build (tagsfile new)
  (let (db
        tbl
        (vec (make-vector ac-ctags-vector-default-size 0))
        (lst ac-ctags-current-tags-list)
        new-lst)
    (setq new-lst (ac-ctags-update-tags-list tagsfile new))
    (unless (or (null new-lst) (equal lst new-lst))
      ;; If tags list has changed, we update the information
      (message  "ac-ctags: Building completion table...")
      (setq db (ac-ctags-build-tagsdb new-lst db))
      (setq tbl (ac-ctags-build-completion-table db))
      (setq vec (ac-ctags-build-current-completion-table vec tbl))
      ;; Update the state.
      (setq ac-ctags-tags-db db
            ac-ctags-completion-table tbl
            ac-ctags-current-completion-table vec)
      (message "ac-ctags: Building completion table...done"))))

(defun ac-ctags-create-new-list-p (tagsfile)
  "Ask user whether to create the new tags file list or use the
current one. TAGSFILE is guaranteed to be a valid tagfile."
  ;; Check if TAGSFILE is already in the current list.
  (if (and ac-ctags-current-tags-list
           (member tagsfile ac-ctags-current-tags-list))
      (y-or-n-p "The tags file is already in the current tags list.\nCreate a new list? ")
    ;; If not in the list, ask the user what to do.
    (y-or-n-p "Create new tags list? ")))

(defun ac-ctags-insert-tags-into-new-list (tagsfile)
  "Insert TAGSFILE into a new tags list and return the current
list."
  (setq ac-ctags-current-tags-list (list tagsfile))
  (unless (member ac-ctags-current-tags-list
                  ac-ctags-tags-list-set)
    (push ac-ctags-current-tags-list ac-ctags-tags-list-set))
  ac-ctags-current-tags-list)

(defun ac-ctags-insert-tags-into-current-list (tagsfile)
  "Insert TAGSFILE into the current tags list and return the
current list."
  (unless (member tagsfile ac-ctags-current-tags-list)
    (setq ac-ctags-tags-list-set
          (delete ac-ctags-current-tags-list ac-ctags-tags-list-set))
    (push tagsfile ac-ctags-current-tags-list)
    (push ac-ctags-current-tags-list ac-ctags-tags-list-set)
    ac-ctags-current-tags-list))

(defun ac-ctags-is-valid-tags-file-p (tags)
  "Return t if TAGS is valid tags file created by exuberant
  ctags."
  (let ((fullpath (and tags (file-exists-p tags) (expand-file-name tags)))
        (needle "!_TAG_PROGRAM_NAME	Exuberant Ctags"))
    (when fullpath
      (with-temp-buffer
        ;; So far we think 500 is enough.
        (insert-file-contents-literally fullpath nil 0 500)
        (search-forward needle nil t)))))

(defun ac-ctags-build-tagsdb (tags-list tags-db)
  "Build tagsdb from each element of TAGSLIST."
  (dolist (e tags-list tags-db)
    (setq tags-db (ac-ctags-build-tagsdb-from-tags e tags-db))))

(defun ac-ctags-build-tagsdb-from-tags (tags tags-db)
  "Build tag information db frm TAGS and return the db.
Each element of DB is a list like (name cmd signature) where NAME
  is tag name, CMD is info constructed from EX command, and
  SIGNATURE is as is. If NAME entry has no signature, then
  SIGNATURE is nil.
TAGS is expected to be an absolute path name."
  (assert (ac-ctags-is-valid-tags-file-p tags))
  (with-temp-buffer
    (insert-file-contents-literally tags)
    (goto-char (point-min))
    ;; todo: How can we get the return type? `signature' in tags file
    ;; does not contain the return type.
    (while (re-search-forward
            "^\\([^!\t]+\\)\t[^\t]+\t\\(.*\\);\"\t.*$"
            nil t)
      (let (line name cmd (lang "Others") signature)
        (setq line (match-string-no-properties 0)
              name (match-string-no-properties 1)
              cmd (ac-ctags-trim-whitespace
                   (ac-ctags-strip-cmd (match-string-no-properties 2))))
        ;; If this line contains a language information, we get it.
        (when (string-match "language:\\([^\t\n]+\\)" line)
          (setq lang (match-string-no-properties 1 line)))
        ;; If this line contains a signature, we get it.
        (when (string-match "signature:\\([^\t\n]+\\)" line)
          (setq signature (match-string-no-properties 1 line)))
        (if (assoc lang tags-db)
            (push `(,name ,cmd ,signature)
                  (cdr (assoc lang tags-db)))
          (push `(,lang (,name ,cmd ,signature))
                tags-db)))))
  tags-db)

;; ("C++" (name command signature)...)
(defun ac-ctags-build-completion-table (tags-db)
  "TAGS-DB must be created by ac-ctags-build-tagdb beforehand."
  (let ((tbl nil))
    (dolist (db tags-db)
      ;; Create completion table for each language.
      (let ((lang (car db)) (names (mapcar #'car (cdr db))))
        (if (assoc lang tbl)
            ;; intern each name into the vector
            (mapc (lambda (name) (intern name (cdr (assoc lang tbl))))
                  names)
          (let ((vec (make-vector ac-ctags-vector-default-size 0)))
            (mapc (lambda (name) (intern name vec)) names)
            (push (cons lang vec) tbl)))))
    tbl))

(defun ac-ctags-build-current-completion-table (vec table)
  "Build completion vector"
  (let ((langs (ac-ctags-get-mode-string major-mode)))
    (dolist (l langs)
      (when (cdr (assoc l table))
        (mapatoms (lambda (sym)
                    (intern (symbol-name sym) vec))
                  (cdr (assoc l table)))))
    vec))

(defun ac-ctags-trim-whitespace (str)
  "Trim prepending and trailing whitespaces and return the result
  string."
  (replace-regexp-in-string "[ \t]+$" ""
                            (replace-regexp-in-string "^[ \t]+" "" str)))

(defun ac-ctags-strip-cmd (str)
  (let ((ret (replace-regexp-in-string "^/^" ""
                                       (replace-regexp-in-string "\\$/$" "" str))))
    (replace-regexp-in-string ";$" "" ret)))

;; todo: more accurate signatures are desirable.
;; i.e. not `(double d)' but `void func(double d) const',
;; but for now just return signature entry in tags prepended by name.
(defun ac-ctags-get-signature (name db lang)
  "Return a list of signatures corresponding NAME."
  (loop for e in (cdr (assoc lang db))
        ;; linear searching is not what I want to use...
        when (and (string= name (car e))
                  (not (null (caddr e))))
        collect (concat name (caddr e))))

(defun ac-ctags-get-signature-by-mode (name db mode)
  "Return a list containing signatures corresponding `name'."
  (let ((langs (ac-ctags-get-mode-string mode))
        (sigs nil))
    (when langs
      (dolist (lang langs)
        (let ((siglst (ac-ctags-get-signature name db lang)))
          (when siglst
            (setq sigs (append siglst sigs))))))
    (sort sigs #'string<)))

(defun ac-ctags-reset ()
  "Reset tags list, set, and other data."
  (interactive)
  (setq ac-ctags-current-tags-list nil
        ac-ctags-tags-list-set nil
        ac-ctags-tags-db nil
        ac-ctags-completion-table nil
        ac-ctags-current-completion-table nil
        ac-ctags-current-major-mode nil))

(defun ac-ctags-get-mode-string (mode)
  (or (cadr (assoc mode ac-ctags-mode-to-string-table))
      '("Others")))

;;;;;;;;;;;;;;;;;;;; ac-ctags-select-tags-list-mode ;;;;;;;;;;;;;;;;;;;;
(require 'button)

(defvar ac-ctags-select-tags-list-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map button-buffer-map)
    (define-key map "t" 'push-button)
    (define-key map "j" 'next-line)
    (define-key map "\C-i" 'next-line)
    (define-key map "k" 'previous-line)
    (define-key map "q" 'ac-ctags-select-tags-list-quit)
    map))

(define-button-type 'ac-ctags-select-tags-list-button-type
  'action 'ac-ctags-select-tags-list-select
  'help-echo "RET, t, or mouse-2 to select tags list")

(define-derived-mode ac-ctags-select-tags-list-mode fundamental-mode "Select Tags List"
  "Major mode for selecting a current tags list.

\\{ac-ctags-select-tags-list-mode-map}"
  (setq buffer-read-only t))

(defun ac-ctags-select-tags-list ()
  "Swith to another list of tags."
  (interactive)
  (let ((beg nil) (b nil))
    (setq ac-ctags-window-conf (current-window-configuration))
    (pop-to-buffer "*auto-complete-ctags*")
    (erase-buffer)
    (goto-char (point-min))
    (insert "Type t or Enter on the list you want to use.")
    (newline)
    (newline)
    (setq beg (point))
    (setq b (point))
    ;; First, print the current list on the top of this buffer.
    (princ (mapcar #'abbreviate-file-name ac-ctags-current-tags-list)
           (current-buffer))
    (make-text-button b (point) 'type 'ac-ctags-select-tags-list-button-type
                      'ac-ctags-tags-list ac-ctags-current-tags-list)
    (newline)
    ;; Then, print the rest.
    (when (and ac-ctags-tags-list-set
               (car ac-ctags-tags-list-set)
               (not (null (car (remove ac-ctags-current-tags-list ac-ctags-tags-list-set)))))
      (loop for e in (remove ac-ctags-current-tags-list ac-ctags-tags-list-set)
            do (progn
                 (setq b (point))
                 (princ (mapcar #'abbreviate-file-name e) (current-buffer))
                 (make-text-button b (point) 'type 'ac-ctags-select-tags-list-button-type
                                   'ac-ctags-tags-list e)
                 (newline))))
    (goto-char beg)
    (ac-ctags-select-tags-list-mode)))

(defun ac-ctags-select-tags-list-select (button)
  "Select the tags list on this line."
  (interactive (list (or (button-at (line-beginning-position))
                         (error "No tags list on the current line"))))
  (let ((tagslist (button-get button 'ac-ctags-tags-list)))
    (ac-ctags-select-tags-list-quit)
    ;; If the newly selected tags list is not the same as the current
    ;; one, we switch the current list to the new one.
    (when (and tagslist
               (not (equal ac-ctags-current-tags-list
                           tagslist))
               (ac-ctags-switch tagslist))
      (message "Current tags list: %s" tagslist))))

(defun ac-ctags-switch (tagslist)
  (setq ac-ctags-current-tags-list tagslist)
  (ac-ctags-build tagslist))

(defun ac-ctags-select-tags-list-quit ()
  (interactive)
  (quit-window t (selected-window))
  (set-window-configuration ac-ctags-window-conf))

;;;;;;;;;;;;;;;;;;;; Definition of ac-source-ctags ;;;;;;;;;;;;;;;;;;;;
(defun ac-ctags-candidates ()
  (let ((candidates nil))
    ;; Workaround to include same-mode-candidates and
    ;; ac-dictionary-candidates, which I think are essential.
    (setq candidates
          (sort (append (all-completions ac-target ac-ctags-current-completion-table)
                        (ac-ctags-same-mode-candidates))
                #'string<))
    ;; For now, comment out the below because calling
    ;; ac-buffer-dictionary causes some problems.
    ;; (setq candidates (sort (append (ac-ctags-buffer-dictionary-candidates)
    ;;                                candidates)
    ;;                        #'string<))
    (let ((len (length candidates)))
      (if (and (numberp ac-ctags-candidate-limit)
               (> len ac-ctags-candidate-limit))
          (nbutlast candidates (- len ac-ctags-candidate-limit))
        candidates))))

(defun ac-ctags-same-mode-candidates ()
  (ac-word-candidates
   (lambda (buffer)
     (derived-mode-p (buffer-local-value 'major-mode buffer)))))

(defun ac-ctags-buffer-dictionary-candidates ()
  (ac-buffer-dictionary))

(defun ac-ctags-document (item)
  (let ((func (ac-ctags-get-document-function major-mode ac-ctags-document-function-table)))
    (when func
      (funcall func item))))

(defun ac-ctags-prefix ()
  (or (funcall (ac-ctags-get-prefix-function major-mode ac-ctags-prefix-funtion-table))
      (ac-prefix-symbol)))

(defun ac-ctags-c++-prefix ()
  (let ((c (char-before))
        (bol (save-excursion (beginning-of-line) (point))))
    (cond
     ((and (characterp c) (char-equal c ?:))
      ;; Has just entered `::' ?
      (when (and (char-before (1- (point)))
                 (char-equal (char-before (1- (point))) ?:))
        (save-excursion
          (ac-ctags-skip-delim-backward)
          (if (and (= (point) bol)
                   (ac-ctags-double-colon-p (point)))
              (+ 2 (point))
            (point)))))
     ;; There is `::' on the currently-editing line,
     ;; and has just entered a character other than `:'.
     ((save-excursion
        (re-search-backward "::"
                            (save-excursion
                              (ac-ctags-skip-delim-backward)
                              (point))
                            t))
      (save-excursion
        (ac-ctags-skip-delim-backward)
        (if (ac-ctags-double-colon-p (point))
            (+ 2 (point))
          (point))))
     (t nil))))

(defun ac-ctags-skip-delim-backward ()
  (let ((bol (save-excursion (beginning-of-line) (point)))
        (cont t))
    (while (and cont (search-backward "::" bol t))
      (when (and (char-before) (string-match "[[:alpha:]]" (string (char-before))))
        ;; skip a namespace
        (skip-chars-backward "^* \t;()<>" bol)
        (setq cont nil)))))

(defun ac-ctags-double-colon-p (pos)
  "Return t if characters at position POS and POS+1 are colons."
  (let ((c1 (char-after pos))
        (c2 (char-after (1+ pos))))
    (and (characterp c1)
         (characterp c2)
         (char-equal c1 ?:)
         (char-equal c2 ?:))))

(defun ac-ctags-get-prefix-function (mode table)
  (let ((f (assoc mode table)))
    (if f (cdr f)
      #'ac-prefix-symbol)))

(defun ac-ctags-get-document-function (mode table)
  (cdr (assoc mode table)))

(defun ac-ctags-c++-document (item)
  "Documentation function for c++-mode."
  (let ((lst (ac-ctags-get-signature-by-mode (substring-no-properties item)
                                             ac-ctags-tags-db
                                             'c++-mode)))
    (cond
     ((= (length lst) 1) (car lst))
     ((> (length lst) 1)
      (reduce (lambda (x y) (concat x "\n" y)) lst))
     (t "No documentation available."))))

;; ac-source-ctags
(ac-define-source ctags
  '((candidates . ac-ctags-candidates)
    (candidate-face . ac-ctags-candidate-face)
    (selection-face . ac-ctags-selection-face)
    (document . ac-ctags-document)
    (requires . 2)
    (prefix . ac-ctags-prefix)))

(provide 'auto-complete-ctags)
;;; auto-complete-ctags.el ends here