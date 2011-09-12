(require 'ert)

(defconst test-ac-ctags-valid-tagfile "~/repos/git_repos/auto-complete-ctags/test/test.tags")

(ert-deftest test-ac-ctags-is-valid-tags-file-p ()
  "A test to check whether a tags file is created by Exuberant
ctags."
  (let ((tags (and (cd "~/repos/git_repos/auto-complete-ctags/test/")
                   "./test.tags"))
        (nonexist "./tags"))
    (should (equal t (numberp (ac-ctags-is-valid-tags-file-p tags))))
    (should (equal t (null (ac-ctags-is-valid-tags-file-p nonexist))))
    ;; check for TAGS created by etags.
    (should (equal t (null (ac-ctags-is-valid-tags-file-p "qt.TAGS"))))))

(ert-deftest test-ac-ctags-visit-tags-file ()
  "A test for ac-ctags-visit-tags-file. No fully implemented, so
this test fails."
  :expected-result :failed
  (let ((ret (call-interactively 'ac-ctags-visit-tags-file)))
    (should (equal t (and (not (null ret))
                          (listp ret))))))

(ert-deftest test-ac-ctags-create-new-list-p ()
  "If the user chooses `yes', then the resutl should be
  `t'. Otherwise nil."
  (let ((tags test-ac-ctags-valid-tagfile))
    ;; The answer is to create new one.
    (should (equal t (ac-ctags-create-new-list-p tags)))
    ;; The answer is to use the current one.
    (should (equal nil (ac-ctags-create-new-list-p tags)))
    ;; tags is already in the current list and the answer is to create
    ;; new one.
    (should (equal t (let ((ac-ctags-current-tags-list (list tags)))
                       (ac-ctags-create-new-list-p tags))))
    ;; tags is already in the current list and the answer is to use
    ;; the current.
    (should (equal nil (let ((ac-ctags-current-tags-list (list tags)))
                         (ac-ctags-create-new-list-p tags))))))

(ert-deftest test-ac-ctags-insert-tags-into-new-list ()
  (let ((ac-ctags-current-tags-list nil)
        (ac-ctags-tags-list-set nil))
    (ac-ctags-insert-tags-into-new-list "test.tags")
    (should (equal '(("test.tags")) ac-ctags-tags-list-set))
    (should (equal '("test.tags") ac-ctags-current-tags-list)))
  (let ((ac-ctags-current-tags-list '("old.tags"))
        (ac-ctags-tags-list-set '(("old.tags"))))
    (ac-ctags-insert-tags-into-new-list "test.tags")
    (should (equal '(("test.tags") ("old.tags")) ac-ctags-tags-list-set))
    (should (equal '("test.tags") ac-ctags-current-tags-list)))
  ;; Case that the newly created list has already been in hte set.
  ;; The set should not change.
  (let ((ac-ctags-current-tags-list '("old.tags"))
        (ac-ctags-tags-list-set '(("test.tags") ("old.tags"))))
    (ac-ctags-insert-tags-into-new-list "test.tags")
    (should (equal '(("test.tags") ("old.tags")) ac-ctags-tags-list-set))
    (should (equal '("test.tags") ac-ctags-current-tags-list))))

(ert-deftest test-ac-ctags-insert-tags-into-current-list ()
  "A test for inserting tags into the current tags list."
  (let ((ac-ctags-current-tags-list nil)
        (ac-ctags-tags-list-set nil))
    (ac-ctags-insert-tags-into-current-list "new.tags")
    (should (equal '("new.tags")
                   ac-ctags-current-tags-list))
    (should (equal '(("new.tags"))
                   ac-ctags-tags-list-set)))
  (let ((ac-ctags-current-tags-list '("tags1"))
        (ac-ctags-tags-list-set '(("tags1") ("tags2"))))
    (ac-ctags-insert-tags-into-current-list "new.tags")
    (should (equal '("new.tags" "tags1")
                   ac-ctags-current-tags-list))
    (should (equal '(("new.tags" "tags1") ("tags2"))
                   ac-ctags-tags-list-set)))
  (let ((ac-ctags-current-tags-list '("tags1"))
        (ac-ctags-tags-list-set '(("tags2"))))
    (ac-ctags-insert-tags-into-current-list "new.tags")
    (should (equal '("new.tags" "tags1")
                   ac-ctags-current-tags-list))
    (should (equal '(("new.tags" "tags1") ("tags2"))
                   ac-ctags-tags-list-set))))

(ert-deftest test-ac-ctags-build-tagdb-from-tags ()
  (let* ((tags (expand-file-name test-ac-ctags-valid-tagfile))
        (db (ac-ctags-build-tagdb-from-tags tags)))
    (should (and (> (length db) 1)
                 (listp db)))
    (should (listp (car db)))
    ;; Check if the length of each element is 3.
    (should (loop for e in db
                  do (unless (= (length e) 3) (return nil))
                  finally return t)))))

(ert-deftest test-ac-ctags-trim-whitespace ()
  (should (string= "Hi" (ac-ctags-trim-whitespace "  	Hi")))
  (should (string= "Hi" (ac-ctags-trim-whitespace "Hi   	")))
  (should (string= "Hi" (ac-ctags-trim-whitespace "  	Hi		  ")))
  (should (string= "Hi" (ac-ctags-trim-whitespace "Hi"))))