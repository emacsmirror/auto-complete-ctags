(require 'ert)
(require 'cl)

(require 'auto-complete-ctags)
(require 'auto-complete-ctags-cpp)
(require 'auto-complete-ctags-java)

(defconst test-ac-ctags-valid-tagfile "cpp.ctags")
(defconst test-ac-ctags-valid-gtest-tagfile "gtest.ctags")
(defconst test-ac-ctags-cpp-tagsfile "cpp.ctags")
(defconst test-ac-ctags-cpp-tagsfile2 "test_with_q.ctags")
(defconst test-ac-ctags-cpp-tagsfile3 "cc.ctags")
(defconst test-ac-ctags-java-tagsfile "java.new.tags")
(defconst test-ac-ctags-java-tagsfile2 "java.ctags")
(defconst test-ac-ctags-java-goos-tagfile "goos.ctags")
(defconst test-ac-ctags-c-tagsfile "c.ctags")
(defconst test-ac-ctags-java-tagsfile-for-update "java.updated.ctags")
(defconst test-ac-ctags-java-inf-tagsfile "inf.ctags")
(defconst test-ac-ctags-qt-tags-file "qt.ctags")
(defconst test-ac-ctags-cpp-macro-and-ns-tagfile "test2.ctags")
(defconst test-ac-ctags-cpp-stl-vector-tagfile "stl_vector.ctags")

(defconst test-ac-ctags-node-length 10)

(defun test-ac-ctags-fixture (body)
  (let ((ac-ctags-current-major-mode nil)
        (ac-ctags-tags-db nil)
        (ac-ctags-current-tags-list nil)
        (ac-ctags-tags-list-set nil)
        (ac-ctags-completion-table nil)
        (ac-ctags-current-completion-table nil)
        (ac-ctags-tags-db-created-time nil)
        (ac-ctags-cache-)
        (ac-ctags-top-level-hash-table (make-hash-table :test #'equal)))
    (funcall body)))

(defun* test-ac-ctags-make-node (&key (name nil) (file nil) (cmd nil) (kind nil)
                                      (class nil) (interface nil) (signature nil)
                                      (enum nil) (returntype nil) (namespace nil))
  (list name file cmd kind class interface signature enum returntype namespace))

(defun test-ac-ctags-before (file)
  (with-temp-buffer
    (insert-file-contents-literally file)
    (eval-buffer)))

;(test-ac-ctags-before "../auto-complete-ctags.el")
;(test-ac-ctags-before "../auto-complete-ctags-java.el")

(ert-deftest test-ac-ctags-is-valid-tags-file-p ()
  "A test to check whether a tags file is created by Exuberant
ctags."
  (let ((tags test-ac-ctags-valid-tagfile)
        (nonexist "./non.tags"))
    (should (numberp (ac-ctags-is-valid-tags-file-p tags)))
    (should (null (ac-ctags-is-valid-tags-file-p nonexist)))
    ;; check for TAGS created by etags.
    (should (null (ac-ctags-is-valid-tags-file-p "e.TAGS")))))

(ert-deftest test-ac-ctags-create-new-list-p ()
  "If the user chooses `yes', then the resutl should be
  `t'. Otherwise nil."
  (let ((tags test-ac-ctags-valid-tagfile))
    ;; The answer is to create new one.
    ;; You have to answer `yes'
    (should (ac-ctags-create-new-list-p tags))
    ;; The answer is to use the current one.
    ;; You have to answer `no'
    (should (null (ac-ctags-create-new-list-p tags)))
    ;; tags is already in the current list and the answer is to create
    ;; new one.
    ;; You have to answer `yes'
    (should (let ((ac-ctags-current-tags-list (list tags)))
              (ac-ctags-create-new-list-p tags)))
    ;; tags is already in the current list and the answer is to use
    ;; the current.
    ;; You have to answer `no'
    (should (null (let ((ac-ctags-current-tags-list (list tags)))
                    (ac-ctags-create-new-list-p tags))))))

(ert-deftest test-ac-ctags-insert-tags-into-new-list ()
  (test-ac-ctags-fixture
   (lambda ()
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
     ;; Case that the newly created list has already been in the set.
     ;; The set should not change.
     (let ((ac-ctags-current-tags-list '("old.tags"))
           (ac-ctags-tags-list-set '(("test.tags") ("old.tags"))))
       (ac-ctags-insert-tags-into-new-list "test.tags")
       (should (equal '(("test.tags") ("old.tags")) ac-ctags-tags-list-set))
       (should (equal '("test.tags") ac-ctags-current-tags-list))))))

(ert-deftest test-ac-ctags-insert-tags-into-current-list ()
  "A test for inserting tags into the current tags list."
  (test-ac-ctags-fixture
   (lambda ()
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
                      ac-ctags-tags-list-set))))))

(ert-deftest test-ac-ctags-build-tagsdb-from-tags:c-tags ()
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((tags (expand-file-name test-ac-ctags-c-tagsfile))
            (tbl nil))
       (ac-ctags-build-tagsdb-from-tags tags)
       (setq tbl (gethash "C" (ac-ctags-get-lang-hash-table-for-tagfile tags)))
       (should (hash-table-p tbl))
       (should (< 0 (hash-table-count tbl)))
       ;; Check if the length of each element is test-ac-ctags-node-length.
       (loop for nodes being the hash-values of tbl
             do (loop for node in nodes
                      do (should (= (length node) test-ac-ctags-node-length))))))))

(ert-deftest test-ac-ctags-build-tagsdb-from-tags:cpp-tags ()
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((tags (expand-file-name test-ac-ctags-cpp-tagsfile))
            (tbl nil))
       (ac-ctags-build-tagsdb-from-tags tags)
       (setq tbl (gethash "C++" (ac-ctags-get-lang-hash-table-for-tagfile tags)))
       (should (hash-table-p tbl))
       (should (< 0 (hash-table-count tbl)))
       ;; Check if the length of each element is equal to test-ac-ctags-node-length
       (loop for nodes being the hash-values of tbl
             do (loop for node in nodes
                      do (should (= (length node) test-ac-ctags-node-length))))))))


(ert-deftest test-ac-ctags-build-tagsdb-from-tags:java-tags ()
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((tags (expand-file-name test-ac-ctags-java-tagsfile))
            (tbl nil))
       (ac-ctags-build-tagsdb-from-tags tags)
       (setq tbl (gethash "Java" (ac-ctags-get-lang-hash-table-for-tagfile tags)))
       (should (hash-table-p tbl))
       (should (< 0 (hash-table-count tbl)))
       ;; Check if the length of each element is equal to test-ac-ctags-node-length
       (loop for nodes being the hash-values of tbl
             do (loop for node in nodes
                      do (should (= (length node) test-ac-ctags-node-length))))))))

(ert-deftest test-ac-ctags-build-tagsdb-from-tags:java-check-returntype ()
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((tags (expand-file-name test-ac-ctags-java-tagsfile2))
            (tbl nil)
            (case-fold-search nil)
            (count 0))
       (ac-ctags-build-tagsdb-from-tags tags)
       (setq tbl (gethash "Java" (ac-ctags-get-lang-hash-table-for-tagfile tags)))
       (should (hash-table-p tbl))
       (should (< 0 (hash-table-count tbl)))
       (loop for val being the hash-values of tbl
             do (loop for node in val
                      when (and (string= "method"
                                         (ac-ctags-node-kind node))
                                (string-match "^[a-z].*$" (ac-ctags-node-name node)))
                      do (should (prog1 (stringp (ac-ctags-node-returntype node))
                                   (incf count)))))
       (should (< 0 count))))))

(ert-deftest test-ac-ctags-build-tagsdb-from-tags:cpp-check-returntype ()
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((tags (expand-file-name test-ac-ctags-cpp-tagsfile))
            (tbl nil)
            (case-fold-search nil)
            (count 0))
       (ac-ctags-build-tagsdb-from-tags tags)
       (setq tbl (gethash "C++" (ac-ctags-get-lang-hash-table-for-tagfile tags)))
       (should (hash-table-p tbl))
       (should (< 0 (hash-table-count tbl)))
       (loop for val being the hash-values of tbl
             do (loop for node in val
                      when (and (member (ac-ctags-node-kind node)
                                        '("function" "prototype"))
                                (string-match-p "^[a-z].*$" (ac-ctags-node-name node)))
                      do (should (prog1 (stringp (ac-ctags-node-returntype node))
                                   (incf count)))))
       (should (< 0 count))))))

(ert-deftest test-ac-ctags-build-tagsdb-from-tags:c-check-returntype ()
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((tags (expand-file-name test-ac-ctags-c-tagsfile))
            (tbl nil)
            (case-fold-search nil)
            (count 0))
       (ac-ctags-build-tagsdb-from-tags tags)
       (setq tbl (gethash "C" (ac-ctags-get-lang-hash-table-for-tagfile tags)))
       (should (hash-table-p tbl))
       (should (< 0 (hash-table-count tbl)))
       (loop for val being the hash-values of tbl
             do (loop for node in val
                      when (and (member (ac-ctags-node-kind node)
                                        '("function" "prototype"))
                                (string-match "^[a-z].*$" (ac-ctags-node-name node)))
                      do (should (prog1 (stringp (ac-ctags-node-returntype node))
                                   (incf count)))))
       (should (< 0 count))))))

(ert-deftest test-ac-ctags-trim-whitespace ()
  (should (string= "Hi" (ac-ctags-trim-whitespace "  	Hi")))
  (should (string= "Hi" (ac-ctags-trim-whitespace "Hi   	")))
  (should (string= "Hi" (ac-ctags-trim-whitespace "  	Hi		  ")))
  (should (string= "Hi" (ac-ctags-trim-whitespace "Hi"))))

(ert-deftest test-ac-ctags-build-tagsdb:cpp-and-java ()
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((tags-list `(,test-ac-ctags-cpp-tagsfile ,test-ac-ctags-java-tagsfile))
            (cpp-tbl nil)
            (java-tbl nil))
       (ac-ctags-build-tagsdb tags-list)
       (should (= 2 (hash-table-count ac-ctags-top-level-hash-table)))
       ;; Check cpp-db
       (setq cpp-tbl (gethash "C++" (ac-ctags-get-lang-hash-table-for-tagfile
                                     test-ac-ctags-cpp-tagsfile)))
       (should (hash-table-p cpp-tbl))
       (should (> (hash-table-count cpp-tbl) 0))
       (loop for nodes being the hash-values of cpp-tbl
             do (loop for node in nodes
                      do (should (= (length node) test-ac-ctags-node-length))))

       ;; Check java-db
       (setq java-tbl (gethash "Java"
                               (ac-ctags-get-lang-hash-table-for-tagfile
                                test-ac-ctags-java-tagsfile)))
       (should (hash-table-p java-tbl))
       (should (> (hash-table-count java-tbl) 0))
       (loop for nodes being the hash-values of java-tbl
             do (loop for node in nodes
                      do (should (= (length node) test-ac-ctags-node-length))))))))

(ert-deftest test-ac-ctags-get-signature ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-reset)
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     (should (equal '("void normal_func()")
                    (ac-ctags-get-signature "normal_func" "C++")))
     (should
      (null (ac-ctags-get-signature "TestClass::normal_func" "C++")))
     (should (equal '("void overloaded_func(double d)" "void overloaded_func(int i)" )
                    (ac-ctags-get-signature "overloaded_func" "C++")))
     ;;(should (equal '("void risky_func() throw (int)")
                    (ac-ctags-get-signature "risky_func" "C++")))
     (should (null (ac-ctags-get-signature "TestClass" "C++")))
     (should (null (ac-ctags-get-signature "nonexist" "C++")))
     )

(ert-deftest test-ac-ctags-get-signature:gtest ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-valid-gtest-tagfile 'new)
     (should
      (equal '("void InitGoogleTest(int* argc, char** argv)"
               "void InitGoogleTest(int* argc, wchar_t** argv)")
             (ac-ctags-get-signature "InitGoogleTest" "C++")))
     (should
      (null (ac-ctags-get-signature "EXPECT_EQ" "C++"))))))

(ert-deftest test-ac-ctags-get-signature-by-mode ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     (should (equal '("void normal_func()")
                    (ac-ctags-get-signature "normal_func" "C++"))))))

(ert-deftest test-ac-ctags-c++-document ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     (should
      (string= "void overloaded_func(double d)\nvoid overloaded_func(int i)"
               (ac-ctags-c++-document "overloaded_func")))
     (should
      (string= "void normal_func()"
               (ac-ctags-c++-document "normal_func")))
     (should
      (string= "void risky_func()"
               (ac-ctags-c++-document "risky_func")))
     )))

(ert-deftest test-ac-ctags-c-document ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-c-tagsfile 'new)
     (should
      (string= "void simple_func(void)"
               (ac-ctags-c-document "simple_func")))
     (should
      (string= "void simple_func2(int a, int b)"
               (ac-ctags-c-document "simple_func2")))
     (should
      (string= ac-ctags-no-document-message
               (ac-ctags-c-document "old_style_func"))))))

(ert-deftest test-ac-ctags-get-mode-string ()
  (should (equal '("C++" "C")
                 (ac-ctags-get-mode-string 'c++-mode)))
  (should (equal '("Java")
                 (ac-ctags-get-mode-string 'java-mode)))
  (should (equal '("Others")
                 (ac-ctags-get-mode-string 'foo-mode))))

(ert-deftest test-ac-ctags-visit-tags-file:list-is-empty ()
  (test-ac-ctags-fixture
   (lambda ()
     (let ((test-tagsfile (expand-file-name test-ac-ctags-valid-tagfile))
           (default-tagsfile (expand-file-name "./tags")))
       ;; Try to insert a new tag into an emtpy tags list.
       (let ((ac-ctags-current-tags-list nil)
             (ac-ctags-tags-list-set nil))
         (ac-ctags-visit-tags-file test-tagsfile 'new)
         (should (equal `(,test-tagsfile)
                        ac-ctags-current-tags-list))
         (should (equal `(,ac-ctags-current-tags-list)
                        ac-ctags-tags-list-set)))))))

(ert-deftest test-ac-ctags-visit-tags-file:list-has-already-the-same-tags ()
  (test-ac-ctags-fixture
   (lambda ()
     ;; Try to insert a tags into a list which has already that tags.
     ;; It won't create a new list.
     (let* ((test-tagsfile (expand-file-name test-ac-ctags-valid-tagfile)))
       ;; visit the same tags file twice
       (ac-ctags-visit-tags-file test-tagsfile 'new)
       (ac-ctags-visit-tags-file test-tagsfile 'current)
       (should (equal `(,test-tagsfile)
                      ac-ctags-current-tags-list))
       (should (equal `((,test-tagsfile))
                      ac-ctags-tags-list-set))))))

(ert-deftest test-ac-ctags-visit-tags-file:try-to-insert-the-same-tags ()
  (test-ac-ctags-fixture
   (lambda ()
     ;; Try to insert a tags into a new list. Try to crate a new list,
     ;; but the elements are the same as those of
     ;; ac-ctags-current-tags-list, so actually does not create a new
     ;; list even if the answer to the create-a-new-list question is
     ;; yes.
     (let* ((test-tagsfile (expand-file-name test-ac-ctags-valid-tagfile))
            (ac-ctags-current-tags-list '(,test-tagsfile)))
       (ac-ctags-visit-tags-file test-tagsfile 'new)
       (should (equal `(,test-tagsfile)
                      ac-ctags-current-tags-list))
       (should (equal `((,test-tagsfile))
                      ac-ctags-tags-list-set))))))

(ert-deftest test-ac-ctags-visit-tags-file:try-to-insert-a-new-tags-into-the-current-list ()
  ;; Try to insert a new tags file into the current list which has
  ;; one elements.
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((test-tagsfile (expand-file-name test-ac-ctags-valid-tagfile))
            (default-tagsfile (expand-file-name "./c.tags"))
            (ac-ctags-current-tags-list `(,test-tagsfile))
            (ac-ctags-tags-list-set `((,test-tagsfile))))
       (ac-ctags-visit-tags-file default-tagsfile 'current)
       (should (equal `(,default-tagsfile ,test-tagsfile)
                      ac-ctags-current-tags-list))
       (should (equal `(,ac-ctags-current-tags-list)
                      ac-ctags-tags-list-set))))))

(ert-deftest test-ac-ctags-visit-tags-file:insert-tags-into-a-new-list ()
  ;; Try to insert a tags into a new list.
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((test-tagsfile (expand-file-name test-ac-ctags-valid-tagfile))
            (default-tagsfile (expand-file-name "./tags"))
            (ac-ctags-current-tags-list `(,test-tagsfile))
            (ac-ctags-tags-list-set `((,test-tagsfile))))
       (ac-ctags-visit-tags-file default-tagsfile 'new)
       (should (equal `(,default-tagsfile)
                      ac-ctags-current-tags-list))
       (should (equal `(,ac-ctags-current-tags-list (,test-tagsfile))
                      ac-ctags-tags-list-set))))))

(ert-deftest test-ac-ctags-visit-tags-file:list-A-into-AB ()
  ;; ac-ctags-current-tags-list => (tagsB)
  ;; ac-ctags-tags-list-set => ((tagsA) (tagsB))
  ;; visiting tagsA
  (test-ac-ctags-fixture
   (lambda ()
     (let* ((test-tagsfile (expand-file-name test-ac-ctags-valid-tagfile))
            (default-tagsfile (expand-file-name "./tags"))
            (ac-ctags-current-tags-list `(,default-tagsfile))
            (ac-ctags-tags-list-set `((,test-tagsfile) (,default-tagsfile))))
       (ac-ctags-visit-tags-file test-tagsfile 'new)
       (should (equal `(,test-tagsfile) ac-ctags-current-tags-list))
       ;; ac-ctags-tags-list-set should stay the same.
       (should (equal `((,test-tagsfile) (,default-tagsfile))
                      ac-ctags-tags-list-set))))))

(ert-deftest test-ac-ctags-strip-cmd ()
  (let ((cmd "public function EscapeToken($token, $chars = null) {"))
    (should (string= "public function EscapeToken($token, $chars = null) {"
                     (ac-ctags-strip-cmd cmd))))
  (let ((cmd "/^		$xmlText = '<' . '?xml version=\"1.0\" encoding=\"UTF-8\"?><tags><tag><id>1<\/id><name>defect<\/name><\/tag><tag><id>2<\/id><name>enhancement<\/name><\/tag><\/tags>';$/"))
    (should (string= "		$xmlText = '<' . '?xml version=\"1.0\" encoding=\"UTF-8\"?><tags><tag><id>1<\/id><name>defect<\/name><\/tag><tag><id>2<\/id><name>enhancement<\/name><\/tag><\/tags>'"
                     (ac-ctags-strip-cmd cmd)))))

(ert-deftest test-ac-ctags-construct-signature ()
  (test-ac-ctags-fixture
   (lambda ()
     (should
      (string= "void normal_func()"
               (ac-ctags-construct-signature
                (test-ac-ctags-make-node :name "normal_func"
                                         :cmd "void normal_func() {}"
                                         :kind "function"
                                         :signature "()" :returntype "void"))))
     (should
      (string= "int get() const"
               (ac-ctags-construct-signature
                (test-ac-ctags-make-node :name "get"
                                         :cmd "int get() const { return 0; }"
                                         :kind "function" :signature "() const" :returntype "int"))))
     (should
      (string= "void TestClass::normal_func()"
               (ac-ctags-construct-signature
                (test-ac-ctags-make-node :name "TestClass::normal_func"
                                         :cmd "void normal_func() {}"
                                         :kind "function" :signature "()" :returntype "void"))))
     (should
      (string= "void InitGoogleTest(int* argc, wchar_t** argv)"
               (ac-ctags-construct-signature
                (test-ac-ctags-make-node
                 :name "InitGoogleTest"
                 :cmd "GTEST_API_ void InitGoogleTest(int* argc, wchar_t** argv)"
                 :kind "prototype" :signature "(int* argc, wchar_t** argv)" :returntype "void")))))))

(ert-deftest test-ac-ctags-construct-signature:throw ()
  :expected-result :failed
  ;; this test fails for now
  (should
   (string= "void risky_func() throw (int)"
            (ac-ctags-construct-signature
             (test-ac-ctags-make-node
              :name "risky_func" :cmd "void risky_func() throw (int)"
              :kind "prototype" :signature "()" :returntype "void")))))

(ert-deftest test-ac-ctags-construct-signature:java ()
  (should
   (string= "void helloWorld()"
            (ac-ctags-construct-signature
             (test-ac-ctags-make-node :name "helloWorld"
                                      :cmd "public void helloWorld() {"
                                      :kind "method"
                                      :signature "()"
                                      :returntype "void"))))
  (should
   (string= "void Test.helloWorld()"
            (ac-ctags-construct-signature
             (test-ac-ctags-make-node :name "Test.helloWorld"
                                      :cmd "public void helloWorld() {"
                                      :kind "method"
                                      :signature "()"
                                      :returntype "void"))))
  (should
   (string= "void helloWorld()"
            (ac-ctags-construct-signature
             (test-ac-ctags-make-node :name "helloWorld"
                                      :cmd "helloWorld()"
                                      :kind "method"
                                      :signature "()"
                                      :returntype "void")))))

(ert-deftest test-ac-ctags-strip-class-name ()
  (should (string= "normal_func"
                   (ac-ctags-strip-class-name "TestClass::normal_func")))
  (should (string= "helloWorld"
                   (ac-ctags-strip-class-name "Test.helloWorld"))))

;; node => (name cmd kind signature)
(ert-deftest test-ac-ctags-node-access ()
  (let ((node
         '("name" "file" "cmd" "kind" "class" "interface"
           "signature" "enum" "returntype" "namespace")))
    (should (string= "name"
                     (ac-ctags-node-name node)))
    (should (string= "cmd"
                     (ac-ctags-node-command node)))
    (should (string= "kind"
                     (ac-ctags-node-kind node)))
    (should (string= "class"
                     (ac-ctags-node-class node)))
    (should (string= "signature"
                     (ac-ctags-node-signature node)))
    (should (string= "enum"
                     (ac-ctags-node-enum node)))
    (should (string= "returntype"
                     (ac-ctags-node-returntype node)))
    (should (string= "namespace"
                     (ac-ctags-node-namespace node)))
    (should (null
             (ac-ctags-node-kind '("name" nil "cmd" nil "class" "interface" "signature"))))
    (should (null
             (ac-ctags-node-signature '("name" nil "cmd" nil "class" "interface" nil))))))

(ert-deftest test-ac-ctags-get-signature:java ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile 'new)
     (should
      ;; should we include public/protected/private as a part of signature?
      (equal '("void helloWorld()")
             (ac-ctags-get-signature "helloWorld"
                                     "Java"))))))

;; fail
;; we have to decide whether we include access keyword in method signature.
(ert-deftest test-ac-ctags-java-document ()
  :expected-result :failed
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile 'new)
     (should
      (string= "public void helloWorld()"
               (ac-ctags-java-document "helloWorld")))
     (should
      (string= "private int helloAnotherWorld() throws NullPointerException"
               (ac-ctags-java-document "helloAnotherWorld")))
     (should
      (string= "public void Test.helloWorld()"
               (ac-ctags-java-document "Test.helloWorld")))
     )))

(ert-deftest test-ac-ctags-java-method-candidates-1 ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
     (should
      (equal
       '("SampleClass()" "SampleClass(int arg1, String arg2)" "helloAnotherWorld()"
         "helloWorld()" "methodThatHasArgument(int i, String str)"
         "methodThatSpansMultipleLines()" "methodWithGenerics()")
       (mapcar #'substring-no-properties
               (ac-ctags-java-method-candidates-1 "SampleClass" nil))))
     (should
      (equal
       '("helloAnotherWorld()")
       (mapcar #'substring-no-properties
               (ac-ctags-java-method-candidates-1 "SampleClass" "helloA"))))
     (should
      (null
       (ac-ctags-java-method-candidates-1 "SampleClass" "none")))
     (should
      (null (ac-ctags-java-method-candidates-1 nil nil)))
     )))

(ert-deftest test-ac-ctags-java-method-candidates-1-check-text-property ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
     (let* ((cand (car (ac-ctags-java-method-candidates-1 "SampleClass" "helloA")))
            (prop (get-text-property 0 'view cand)))
       (should prop)
       ;; method name
       (should (string= "helloAnotherWorld()" (substring-no-properties cand)))
       ;; and view property
       (should (string= "helloAnotherWorld()   :int - SampleClass"
                        prop))
       ))))

(ert-deftest test-ac-ctags-java-collect-methods-in-class ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
     (should
      (equal
       '("SampleClass()" "SampleClass(int arg1, String arg2)" "helloAnotherWorld()"
         "helloWorld()" "methodThatHasArgument(int i, String str)"
         "methodThatSpansMultipleLines()" "methodWithGenerics()")
       (mapcar #'substring-no-properties
               (ac-ctags-java-collect-methods-in-class "SampleClass" nil))))
     (should
      (null (ac-ctags-java-collect-methods-in-class "NoneExist" nil)))
     )))

(ert-deftest test-ac-ctags-java-collect-methods-in-interface ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-inf-tagsfile 'new)
     (should
      (equal
       '("method1(int i)" "method2()")
       (mapcar #'substring-no-properties
               (ac-ctags-java-collect-methods-in-class "SomeInterface" "me")))))))

(ert-deftest test-ac-ctags-java-make-method-candidate ()
  (let ((node1 (test-ac-ctags-make-node :name "method" :kind "method" :class "SomeClass"
                                        :signature "()" :returntype "int"))
        (node2 (test-ac-ctags-make-node :name "anotherMethod" :kind "method" :class "SomeClass"
                                        :signature "(int i, String s)" :returntype "void"))
        (node-ctor (test-ac-ctags-make-node :name "SampleClass" :kind "method" :class "SampleClass"
                                            :signature "()")))
    (should
     (string= "method()"
              (substring-no-properties (ac-ctags-java-make-method-candidate node1))))
    (should
     (string= "method()                :int - SomeClass"
              (get-text-property 0 'view (ac-ctags-java-make-method-candidate node1))))
    (should
     (string= "()"
      (get-text-property 0 'signature (ac-ctags-java-make-method-candidate node1))))
    (should
     (string= "anotherMethod(int i, String s)"
              (ac-ctags-java-make-method-candidate node2)))
    (should
     (string= "anotherMethod(int i, String s)    :void - SomeClass"
              (get-text-property 0 'view (ac-ctags-java-make-method-candidate node2))))
    (should
     (string= "(int i, String s)"
      (get-text-property 0 'signature (ac-ctags-java-make-method-candidate node2))))
    (should
     (string= "SampleClass()"
              (ac-ctags-java-make-method-candidate node-ctor)))
    (should
     (string= "SampleClass()              - SampleClass"
              (get-text-property 0 'view
                                 (ac-ctags-java-make-method-candidate node-ctor))))
    (should
     (string= "()"
      (get-text-property 0 'signature (ac-ctags-java-make-method-candidate node-ctor))))
    ))

(ert-deftest test-ac-ctags-make-yasnippet-template-from-signature ()
  (should
   (string=
    "(${1:int i}, ${2:String s})$0"
    (ac-ctags-make-yasnippet-template-from-signature "(int i, String s)")))
  (should
   (string= "()$0"
            (ac-ctags-make-yasnippet-template-from-signature "()")))
  (should
   (string= "(${1:int i})$0"
            (ac-ctags-make-yasnippet-template-from-signature "(int i)")))
  (should
   (string=
    "(${1:Map<String, String> map})$0"
    (ac-ctags-make-yasnippet-template-from-signature "(Map<String, String> map)")))
  (should
   (string=
    "(${1:Map<String, String> map}, ${2:int j})$0"
    (ac-ctags-make-yasnippet-template-from-signature "(Map<String, String> map, int j)")))
  (should
   (string=
    "(${1:QWidget *parent = 0})$0"
    (ac-ctags-make-yasnippet-template-from-signature
     "(QWidget *parent = 0)")))
  )


(ert-deftest test-ac-ctags-split-signature-string ()
  (should
   (equal '("int i" "int j")
          (ac-ctags-split-signature-string "(int i, int j)" "[,]")))
  (should
   (equal '("Map<String, String> map" "int j")
          (ac-ctags-split-signature-string "(Map<String, String> map, int j)" "[,]")))
  (should
   (equal '("int i")
          (ac-ctags-split-signature-string "(int i)" ",")))
  (should
   (null (ac-ctags-split-signature-string "()" ",")))
  (should
   (equal '("Map<Map<int, int>, Map<int, int>> map" "int i")
          (ac-ctags-split-signature-string "(Map<Map<int, int>, Map<int, int>> map, int i)" ","))))

(ert-deftest test-ac-ctags-java-extract-class-name ()
  (should
   (string= "ClassName"
            (ac-ctags-java-extract-class-name
             "ClassName varname;"
             "varname")))
  (should
   (string= "ClassName"
            (ac-ctags-java-extract-class-name
             "ClassName<Some<Another>> varname;"
             "varname")))
  (should
   (string= "ClassName"
            (ac-ctags-java-extract-class-name
             "public void someMethod(ClassName varname) {"
             "varname"))))

(ert-deftest tet-ac-ctags-java-collect-fields-in-class ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
     (should
      (equal
       '("CONSTANT" "_intField" "_strField" "_strMap")
       (ac-ctags-java-collect-fields-in-class "SampleClass" nil))))))

(ert-deftest test-ac-ctags-java-field-candidates-1 ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
     (should
      (equal
       '("CONSTANT" "_intField" "_strField" "_strMap")
       (ac-ctags-java-field-candidates-1 "SampleClass" nil)))
     (should
      (equal
       '("CONSTANT")
       (ac-ctags-java-field-candidates-1 "SampleClass" "CON")))
     (should
      (null
       (ac-ctags-java-field-candidates-1 "SampleClass" "none")))
     (should
      (null (ac-ctags-java-field-candidates-1 nil nil)))
     )))

(ert-deftest test-ac-ctags-java-make-field-candidate ()
  (let ((node1 (test-ac-ctags-make-node :name "_strField" :cmd "/^  private String _strField;$/;\""
                                        :kind "field" :class "SomeClass"))
        (node2 (test-ac-ctags-make-node :name "_strMap"
                                        :cmd "/^  private Map<String, String> _strMap;$/;\""
                                        :kind "field" :class "SomeClass"))
        (no-type-node (test-ac-ctags-make-node :name "_strMap"
                                               :cmd "/^  private _strMap;$/;\""
                                               :kind "field" :class "SomeClass")))
    (should
     (string= "_strField"
              (ac-ctags-java-make-field-candidate node1)))
    (should
     (string= "_strField                        :String"
              (get-text-property 0 'view (ac-ctags-java-make-field-candidate node1))))
    (should
     (string= "_strMap"
              (ac-ctags-java-make-field-candidate node2)))
    (should
     (string= "_strMap             :Map<String, String>"
              (get-text-property 0 'view (ac-ctags-java-make-field-candidate node2))))
    (should
     (string= "_strMap"
              (ac-ctags-java-make-field-candidate no-type-node)))
    (should
     (null (get-text-property 0 'view (ac-ctags-java-make-field-candidate no-type-node))))
    ))

(ert-deftest test-ac-ctags-java-collect-enums ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-goos-tagfile 'new)
     (should
      (equal '("BIDDING" "JOINING" "LOSING" "LOST" "WINNING" "WON")
             (ac-ctags-java-collect-enums "SniperState" nil))))))

(ert-deftest test-ac-ctags-java-parse-field-node ()
  (should
   (string= "String"
            (ac-ctags-java-parse-field-node
             (test-ac-ctags-make-node :name "_strField" :cmd "/^  private String _strField;$/;\""
                                        :kind "field" :class "SomeClass"))))
  (should
   (string= "Map<String, String>"
            (ac-ctags-java-parse-field-node
             (test-ac-ctags-make-node :name "_strMap"
                                      :cmd "/^  protected Map<String, String> _strMap;$/;\""
                                      :kind "field"
                                      :class "SampleClass"))))
  (should
   (string= "int"
            (ac-ctags-java-parse-field-node
             (test-ac-ctags-make-node :name "CONSTANT"
                                      :cmd "/^  public static final int CONSTANT;$/;\""
                                      :kind "field"
                                      :class "SampleClass"))))
  (should
   (null (ac-ctags-java-parse-field-node
          (test-ac-ctags-make-node :name "CONSTANT"
                                   :cmd "/^  CONSTANT;$/;\""
                                   :kind "field"
                                   :class "SampleClass"))))
  )

(ert-deftest test-ac-ctags-make-signature ()
  (should (string= "(int, int)"
                   (ac-ctags-make-signature "(int a, int b)")))
  (should (string= "(int, int)"
                   (ac-ctags-make-signature "(int, int)")))
  (should (string= "()"
                   (ac-ctags-make-signature "()")))
  (should (string= "(int, String)"
                   (ac-ctags-make-signature "(int i, String str)")))
  (should (string= "()"
                   (ac-ctags-make-signature "(void)")))
  (should (string= "(String...)"
                   (ac-ctags-make-signature "(String... strs)")))
  (should (string= "(int, String...)"
                   (ac-ctags-make-signature "(int i, String... strs)")))
  (should (string= "(int[], int[])"
                   (ac-ctags-make-signature "(int[] arraya, int[] arrayb)")))
  (should (string= "(String)"
                   (ac-ctags-make-signature
                    "(final String s)")))
  (should (string= "(Object, Collection<String>)"
                   (ac-ctags-make-signature "(Object object, Collection<String> strings)")))
  )

(ert-deftest test-ac-ctags-get-ac-sources-by-mode ()
  (should
   (equal '(ac-source-ctags-java-method
            ac-source-ctags-java-enum
            ac-source-ctags-java-field
            ac-source-ctags-java-package)
          (ac-ctags-get-ac-sources-by-mode 'java-mode))))

(ert-deftest test-ac-ctags-candidates-1 ()
  (test-ac-ctags-fixture
   (lambda ()
     (let ((major-mode 'java-mode))
       (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
       (should (ac-ctags-candidates-1 "methodWith"))
       (should-not (ac-ctags-candidates-1 "nonexist"))))))

(ert-deftest test-ac-ctags-check-tags-file-updated ()
  (test-ac-ctags-fixture
   (lambda ()
     (let ((major-mode 'java-mode))
       ;; first, create tags file
       (shell-command
        (concat "ctags -f"
                test-ac-ctags-java-tagsfile-for-update
                " --jcode=utf8 --fields=+aiKlmnSTtz"
                " SampleClassOld.java"))
       (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile-for-update 'new)
       (should-not
        (ac-ctags-candidates-1 "methodWith"))
       ;; next, update tags file
       (sit-for 1)
       (shell-command
        (concat "ctags -f"
                test-ac-ctags-java-tagsfile-for-update
                " --jcode=utf8 --fields=+aiKlmnsSztT"
                " SampleClassNew.java"))
       (should
        (ac-ctags-candidates-1 "methodWith"))
       ))))

(ert-deftest test-ac-ctags-tagsdb-needs-update-p ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     ;; db created time is newer than tags file modification time
     (should-not
      (ac-ctags-tagsdb-needs-update-p (current-time)))
     ;; older than tags file modification time
     (should
      (ac-ctags-tagsdb-needs-update-p '(0 0)))
     )))

(ert-deftest test-ac-ctags-java-parse-before-dot ()
  (should
   (string= "method1"
            (ac-ctags-java-parse-before-dot-part "method1()")))
  (should
   (string= "method1"
            (ac-ctags-java-parse-before-dot-part
             "method1(method2())")))
  (should
   (string= "varname"
            (ac-ctags-java-parse-before-dot-part
             "varname")))
  (should
   (string= "varname"
            (ac-ctags-java-parse-before-dot-part
             "(varname)")))
  (should
   (string= "method1"
            (ac-ctags-java-parse-before-dot-part
             "method1(method2(), method3())")))
  (should
   (string= "method1"
            (ac-ctags-java-parse-before-dot-part
             "method1(method2(), method3(method4()))")))
  (should
   (string= "method2"
            (ac-ctags-java-parse-before-dot-part
             "method1(method2()")))
  (should
   (string= "method3"
            (ac-ctags-java-parse-before-dot-part
             "method1(method2(method3()")))
  (should
   (string= "method1"
            (ac-ctags-java-parse-before-dot-part
             "method1(method2().toString())")))
  (should
   (string= "method1"
            (ac-ctags-java-parse-before-dot-part
             "return method1()")))
  (should
   (string= "SampleClass"
            (ac-ctags-java-parse-before-dot-part
             "new SampleClass()")))
  (should
   (string= "method1"
            (ac-ctags-java-parse-before-dot-part
             "method1(new HashMap<String, new HashMap<int, int>>)"))))

(ert-deftest test-ac-ctags-java-get-method-return-type ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
     (should
      (string= "int"
               (ac-ctags-java-get-method-return-type "helloAnotherWorld")))
     (should
      (null (ac-ctags-java-get-method-return-type "SampleClass"))))))

(ert-deftest test-ac-ctags-java-collect-packages ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-goos-tagfile 'new)
     (should
      (equal '("auctionsniper.ui" "auctionsniper.util" "auctionsniper.xmpp")
             (ac-ctags-java-collect-packages "auctionsniper")))
     (should
      (equal '("auctionsniper.ui" "auctionsniper.util")
             (ac-ctags-java-collect-packages "auctionsniper.u")))
     (should
      (equal '("auctionsniper.ui" "auctionsniper.util" "auctionsniper.xmpp")
             (ac-ctags-java-collect-packages "auctionsniper.")))
     (should
      (null (ac-ctags-java-collect-packages "nonexist")))
     )))

(ert-deftest test-ac-ctags-java-collect-classes-in-package ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-goos-tagfile 'new)
     (should
      (equal '("Announcer" "Defect")
             (ac-ctags-java-collect-classes-in-package "auctionsniper.util")))
     (should
      (null (ac-ctags-java-collect-classes-in-package "non-exisit")))
     )))

(ert-deftest test-ac-ctags-java-package-candidates-1 ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-goos-tagfile 'new)
     (should
      (equal '("auctionsniper.xmpp")
             (ac-ctags-java-package-candidates-1 "auctionsniper.x")))
     (should
      (equal '("auctionsniper.AuctionSniperDriver")
             (ac-ctags-java-package-candidates-1 "auctionsniper.AuctionSniperD"))))))

(ert-deftest test-ac-ctags-java-collect-constructors ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-java-tagsfile2 'new)
     (should
      (equal '("SampleClass()" "SampleClass(int arg1, String arg2)")
             (mapcar #'substring-no-properties
                     (ac-ctags-java-collect-constructors "Samp")))))))

(ert-deftest test-ac-ctags-cpp-parse-before-dot-or-arrow-part ()
  (should
   (string= "varname"
            (ac-ctags-cpp-parse-before-dot-or-arrow-part "varname")))
  (should
   (string= "SomeClass::func1"
            (ac-ctags-cpp-parse-before-dot-or-arrow-part "SomeClass::func1()")))
  (should
   (string= "SomeClass::func1"
            (ac-ctags-cpp-parse-before-dot-or-arrow-part "SomeClass::func1(func2(), func3())")))
  (should
   (string= "varname"
            (ac-ctags-cpp-parse-before-dot-or-arrow-part "(*varname)")))
  (should
   (string= "varname"
            (ac-ctags-cpp-parse-before-dot-or-arrow-part "varname[j]"))))

(ert-deftest test-ac-ctags-cpp-line-has-typeinfo-p ()
  (should
   (ac-ctags-cpp-line-has-typeinfo-p "iter"
                                     "std::vector<int>::const_iterator iter;"))
  (should
   (ac-ctags-cpp-line-has-typeinfo-p "var"
                                     "int* var;"))
  (should
   (ac-ctags-cpp-line-has-typeinfo-p "var"
                                     "SomeClass * var;"))
  (should
   (ac-ctags-cpp-line-has-typeinfo-p
    "var"
    "SomeClass *foo_, *bar_, *var, *buzz_;"))
  (should
   (ac-ctags-cpp-line-has-typeinfo-p
    "mainLayout_"
    "mainLayout_ = new QHBoxLayout;"))
  (should
   (ac-ctags-cpp-line-has-typeinfo-p
    "original"
    "studentCollection::studentCollection(const studentCollection& original)"))
  )

(ert-deftest test-ac-ctags-cpp-extract-type-name ()
  (should
   (string= "QLabel"
            (ac-ctags-cpp-extract-type-name "QLabel *namedLabel_;"
                                            "namedLabel_")))
  (should
   (string= "SomeClass"
            (ac-ctags-cpp-extract-type-name
             "SomeClass *foo_, *bar_, *var, *buzz_;"
             "var")))
  (should
   (string= "std::vector<int>::const_iterator"
            (ac-ctags-cpp-extract-type-name
             "std::vector<int>::const_iterator iter;"
             "iter")))
  (should
   (string= "std::map<int, int>"
            (ac-ctags-cpp-extract-type-name
             "const std::map<int, int> map1, map2, map3;"
             "map2")))
  (should
   (string= "std::vector<int>"
            (ac-ctags-cpp-extract-type-name
             "std::vector<int> vec(10);"
             "vec")))
  (should
   (string= "QHBoxLayout"
            (ac-ctags-cpp-extract-type-name
             "mainLayout_ = new QHBoxLayout;"
             "mainLayout_")))
  (should
   (string= "studentNode"
            (ac-ctags-cpp-extract-type-name
             "  studentNode *from = original->next, *to = newlist;"
             "to")))
  (should
   (string= "studentCollection"
            (ac-ctags-cpp-extract-type-name
             "studentCollection::studentCollection(const studentCollection& original)"
             "original")))
  )

(ert-deftest test-ac-ctags-cpp-strip-aster-and-amp ()
  (should
   (string= "Type" (ac-ctags-cpp-strip-aster-and-amp "Type*")))
  (should
   (string= "Type" (ac-ctags-cpp-strip-aster-and-amp "Type**&"))))

(ert-deftest test-ac-ctags-cpp-get-function-return-type ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     (should
      (string= "void"
               (ac-ctags-cpp-get-function-return-type "set")))
     (should
      (string= "const ParamGeneratorInterface*"
               (ac-ctags-cpp-get-function-return-type
                "BaseGenerator")))
     (should
      (null (ac-ctags-cpp-get-function-return-type "non-exisit"))))))

(ert-deftest test-ac-ctags-cpp-collect-member-functions ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile2 'new)
     (should
      (equal '("set(int i)")
             (mapcar #'substring-no-properties
                     (ac-ctags-cpp-collect-member-functions "TestClass" "se"))))
     (should
      (equal "set(int i)             :void - TestClass"
             (get-text-property 0
                                'view
                                (car
                                 (ac-ctags-cpp-collect-member-functions "TestClass" "set")))))
     (should
      (equal '("TestClass()")
             (ac-ctags-cpp-collect-member-functions "TestClass" "TestC")))
     (should
      (equal '("normal_func()")
             (ac-ctags-cpp-collect-member-functions "TestClass" "normal_"))))))

(ert-deftest test-ac-ctags-cpp-get-typename-of-variable-1 ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile2 'new)
     (should
      (string= "int"
               (ac-ctags-cpp-get-typename-of-variable-1 "i_"))))))

(ert-deftest test-ac-ctags-cpp-get-members-by-scope-operator ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile3 'new)
     (should
      (equal '("get()" "getInstance()" "getObj()" "getObj2()")
             (mapcar #'substring-no-properties
                     (ac-ctags-cpp-get-members-by-scope-operator "TestClass" "ge"))))
     (should
      (equal '("i_")
             (mapcar #'substring-no-properties
                     (ac-ctags-cpp-get-members-by-scope-operator
                      "TestClass" "i"))))
     (should
      (equal '("myns2")
             (mapcar #'substring-no-properties
                     (ac-ctags-cpp-get-members-by-scope-operator "myns1" "")))))))

(ert-deftest test-ac-ctags-cpp-split-string-by-separator ()
  (should
   (equal '("std" "::" "vector<int>" "::")
          (ac-ctags-cpp-split-string-by-separator "std::vector<int>::" "::")))
  (should
   (equal '("std" "::" "vector<int>")
          (ac-ctags-cpp-split-string-by-separator "std::vector<int>" "::"))))

;; std::vector<std::Map>::[]const_iterator
(ert-deftest test-ac-ctags-cpp-parse-before-scope-operator-1 ()
  (should
   (string=
    "std::vector"
    (ac-ctags-cpp-parse-before-scope-operator-1 "std::vector<std::Map>")))
  (should
   (string=
    "std::map"
    (ac-ctags-cpp-parse-before-scope-operator-1 "std::map<std::vector<int>, std::string>")))
  (should
   (string= "testing"
            (ac-ctags-cpp-parse-before-scope-operator-1 "::testing")))
  (should
   (string= "mynamespace::SomeClass"
            (ac-ctags-cpp-parse-before-scope-operator-1 "mynamespace::SomeClass")))
  (should
   (string= "std"
            (ac-ctags-cpp-parse-before-scope-operator-1 "return std")))
  (should
   (string= "std"
            (ac-ctags-cpp-parse-before-scope-operator-1 "using std"))))

(ert-deftest test-ac-ctags-cpp-strip-angle-brackets ()
  (should
   (string=
    "std::vector"
    (ac-ctags-cpp-strip-angle-brackets "std::vector<int>")))
  (should
   (string=
    "std::map"
    (ac-ctags-cpp-strip-angle-brackets "std::map<std::vector<int>, std::string>"))))

(ert-deftest test-ac-ctags-cpp-remove-trailing-keyword-from-signature ()
  (should
   (string= "()"
            (ac-ctags-cpp-remove-trailing-keyword-from-signature "() const")))
  (should
   (string= "(int i, int j)"
            (ac-ctags-cpp-remove-trailing-keyword-from-signature "(int i, int j)"))))

(ert-deftest test-ac-ctags-cpp-strip-typename ()
  (should
   (string= "typename"
            (ac-ctags-cpp-strip-typename "const typename")))
  (should
   (string= "SomeClass"
            (ac-ctags-cpp-strip-typename "SomeClass*")))
  (should
   (string= "SomeClass"
            (ac-ctags-cpp-strip-typename "SomeClass **")))
  (should
   (string= "SomeClass"
            (ac-ctags-cpp-strip-typename "SomeClass * *")))
  (should
   (string= "SomeClass"
            (ac-ctags-cpp-strip-typename "SomeClass* *")))
  (should
   (string= "SomeClass"
            (ac-ctags-cpp-strip-typename "const SomeClass ** const")))
  (should
   (string= "vector"
            (ac-ctags-cpp-strip-typename "vector<int>")))
  (should
   (string= "map"
            (ac-ctags-cpp-strip-typename "map<vector<int>, vector<std::string>>")))
  )

(ert-deftest test-ac-ctags-split-list ()
  (should
   (equal '((1) (2) (3))
          (ac-ctags-split-list '(1 2 3) 1)))
  (should
   (equal '((1 2) (3))
          (ac-ctags-split-list '(1 2 3) 2)))
  (should
   (equal '((1))
          (ac-ctags-split-list '(1) 1)))
  (should
   (equal '((1 2 3))
          (ac-ctags-split-list '(1 2 3) 3)))
  (should
   (equal '((1 2 3))
          (ac-ctags-split-list '(1 2 3) 4))))

(ert-deftest test-ac-ctags-cpp-macro-candidates-1 ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-macro-and-ns-tagfile))
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-macro-and-ns-tagfile 'new)
     (should
      (= 2 (length (ac-ctags-cpp-macro-candidates-1 "MA"))))
     (should
      (equal '("MACRO1" "MACRO2")
             (ac-ctags-cpp-macro-candidates-1 "MA")))
     (should (null (ac-ctags-cpp-macro-candidates-1 "NonExist"))))))

(ert-deftest test-ac-ctags-add-another-tags-in-the-current-list ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     ;; add another tag file into the current list and
     ;; check if there is errors
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile2 'current))))

(ert-deftest test-ac-ctags-cpp-strip-class-name ()
  (should (string= "member1"
                   (ac-ctags-cpp-strip-class-name "foo::bar::member1" "foo::bar")))
  (should (string= "member1"
           (ac-ctags-cpp-strip-class-name "member1" "foo::bar")))
  (should (string= "member1"
                   (ac-ctags-cpp-strip-class-name "ns1::ns2::cls1<int>::member1"
                                                  "ns1::ns2::cls1<int>"))))

(ert-deftest test-ac-ctags-make-hash-key ()
  (should (string= "st" (ac-ctags-make-hash-key "std")))
  (should (string= "std" (ac-ctags-make-hash-key "std::")))
  (should (string= "std" (ac-ctags-make-hash-key "std::vector")))
  (should (string= "std::vector"
                   (ac-ctags-make-hash-key "std::vector::push_back")))
  (should (string= "std::vector"
                   (ac-ctags-make-hash-key "std::vector::")))
  (should (string= ac-ctags-hash-key-for-short-name
                   (ac-ctags-make-hash-key "x")))
  (should (string= "lo"
                   (ac-ctags-make-hash-key "longname_without_double_colon")))
  (should (string= "testing" (ac-ctags-make-hash-key "::testing")))
  (should (string= "testing::internal" (ac-ctags-make-hash-key "::testing::internal::foo")))
  (should (string= "a::b" (ac-ctags-make-hash-key "::a::b::c"))))

(ert-deftest test-ac-ctags-put-node-into-hash-table ()
  (test-ac-ctags-fixture
   (lambda ()
     (let ((dummy-node nil)
           (lang-tbl nil)
           (node-tbl nil))
       (setq dummy-node (test-ac-ctags-make-node :name "std::vector"
                                                 :namespace "std"))
       (ac-ctags-put-node-into-hash-table dummy-node "C++" test-ac-ctags-cpp-tagsfile3)
       (setq lang-tbl (ac-ctags-get-lang-hash-table-for-tagfile test-ac-ctags-cpp-tagsfile3))
       (setq node-tbl (gethash "C++" lang-tbl nil))
       (should (hash-table-p node-tbl))
       (should (equal '("std::vector")
                      (mapcar #'ac-ctags-node-name
                              (gethash "std" node-tbl))))))))

(ert-deftest test-ac-ctags-put-node-into-hash-table-2 ()
  (let ((tbl (make-hash-table :test #'equal))
        (dummy-node nil))
    (ac-ctags-put-node-into-hash-table-2 (test-ac-ctags-make-node :name "std" :kind "namespace")
                                         tbl)
    (should (not (null (gethash (ac-ctags-make-hash-key "std") tbl))))
    (setq dummy-node
          (test-ac-ctags-make-node :name "std::vector"
                                   :namespace "std"))
    (ac-ctags-put-node-into-hash-table-2 dummy-node tbl)
    (should (equal '("std")
                   (sort (mapcar #'ac-ctags-node-name
                                 (ac-ctags-get-nodes-from-hash-table "std" tbl))
                         #'string<)))
    (should (equal '("std::vector")
                   (sort (mapcar #'ac-ctags-node-name
                                 (ac-ctags-get-nodes-from-hash-table "std::" tbl))
                         #'string<)))
    (setq dummy-node
          (test-ac-ctags-make-node :name "std::vector::push_back"
                                   :namespace "std::vector"))
    (ac-ctags-put-node-into-hash-table-2 dummy-node tbl)
    (setq dummy-node
          (test-ac-ctags-make-node :name "std::vector::size"
                                   :namespace "std::vector"))
    (ac-ctags-put-node-into-hash-table-2 dummy-node tbl)
    (should (equal '("std::vector::push_back" "std::vector::size")
                   (sort (mapcar #'ac-ctags-node-name
                                 (ac-ctags-get-nodes-from-hash-table "std::vector::" tbl))
                         #'string<)))
    ;; adding no-scope-operators names
    (setq dummy-node
          (test-ac-ctags-make-node :name "EXPECT_EQ"
                                   :namespace "::ns1"))
    (ac-ctags-put-node-into-hash-table-2 dummy-node tbl)
    (setq dummy-node
          (test-ac-ctags-make-node :name "EXPECT_LT"
                                   :namespace "::ns1"))
    (ac-ctags-put-node-into-hash-table-2 dummy-node tbl)
    (should (equal '("EXPECT_EQ" "EXPECT_LT")
                   (sort (mapcar #'ac-ctags-node-name
                                 (ac-ctags-get-nodes-from-hash-table "EXP" tbl))
                         #'string<)))
    ))

(ert-deftest test-ac-ctags-build-tagsdb-from-tags-with-hashtable:cpp ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-tagsfile3))
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile3 'new)
     (should
      (< 0 (reduce #'+
                   (mapcar #'hash-table-count
                           (ac-ctags-get-node-tables-by-lang "C++"))))))))

(ert-deftest test-ac-ctags-cpp-get-members-by-scope-operator-with-hashtable:cpp ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-tagsfile3))
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile3 'new)
     (equal '("myns2")
            (mapcar #'substring-no-properties
                    (ac-ctags-cpp-get-members-by-scope-operator "myns1" nil)))
     (should
      (equal '("get()" "getInstance()" "getObj()" "getObj2()")
             (mapcar #'substring-no-properties
                     (ac-ctags-cpp-get-members-by-scope-operator "TestClass" "get")))))))

(ert-deftest test-ac-ctags-cpp-get-members-by-scope-operator-with-hashtable:stl_vector ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-stl-vector-tagfile))
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-stl-vector-tagfile 'new)
     (should
      (equal '("vector")
             (sort (remove-duplicates
                    (mapcar #'substring-no-properties
                     (ac-ctags-cpp-get-members-by-scope-operator "std" "v"))
                    :test #'equal)
                   #'string<))))))

(ert-deftest test-ac-ctags-cpp-collect-nodes-by-typename ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-tagsfile3))
     (ac-ctags-visit-tags-file (expand-file-name test-ac-ctags-cpp-tagsfile3) 'new)
     (should
      (equal '("myns1::myns2::InsideClass::member1_")
             (mapcar #'substring-no-properties
                     (mapcar #'ac-ctags-node-name
                             (ac-ctags-cpp-collect-nodes-by-typename "InsideClass"))))))))

(ert-deftest test-ac-ctags-cpp-collect-member-functions-with-hash-table ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-tagsfile3))
     (ac-ctags-visit-tags-file (expand-file-name test-ac-ctags-cpp-tagsfile3) 'new)
     (should
      (equal '("get()" "getInstance()" "getObj()" "getObj2()")
             (sort (mapcar #'substring-no-properties
                           (ac-ctags-cpp-collect-member-functions "TestClass"
                                                                  "get"))
                   #'string<))))))

(ert-deftest test-ac-ctags-cpp-collect-member-functions-with-hash-table:stl_vector ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-stl-vector-tagfile 'new))
     (ac-ctags-visit-tags-file (expand-file-name test-ac-ctags-cpp-stl-vector-tagfile) 'new)
     (should
      (equal '("push_back(bool __x)" "push_back(const value_type& __x)")
             (sort (mapcar #'substring-no-properties
                           (ac-ctags-cpp-collect-member-functions "std::vector"
                                                                  "push"))
                   #'string<))))))

(ert-deftest test-ac-ctags-cpp-collect-member-functions-with-hash-table:two-tags-file ()
  (test-ac-ctags-fixture
   (lambda ()
     (shell-command (format "touch %s" test-ac-ctags-cpp-stl-vector-tagfile 'new))
     (shell-command (format "touch %s" test-ac-ctags-cpp-tagsfile3))
     (ac-ctags-visit-tags-file (expand-file-name test-ac-ctags-cpp-stl-vector-tagfile) 'new)
     (ac-ctags-visit-tags-file (expand-file-name test-ac-ctags-cpp-tagsfile3) 'current)
     (should
      (equal '("push_back(bool __x)" "push_back(const value_type& __x)")
             (sort (mapcar #'substring-no-properties
                           (ac-ctags-cpp-collect-member-functions "std::vector"
                                                                  "push"))
                   #'string<)))
     (should
      (equal '("get()" "getInstance()" "getObj()" "getObj2()")
             (sort (mapcar #'substring-no-properties
                           (ac-ctags-cpp-collect-member-functions "TestClass"
                                                                  "get"))
                   #'string<))))))

(ert-deftest test-ac-ctags-write-hash-table-then-read-in ()
  (test-ac-ctags-fixture
   (lambda ()
     ;; update tag file
     (shell-command (format "touch %s" test-ac-ctags-cpp-tagsfile3))
     ;; this should create a new cache file
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile3 'new)
     (should
      (equal '("get()" "getInstance()" "getObj()" "getObj2()")
             (sort (mapcar #'substring-no-properties
                           (ac-ctags-cpp-collect-member-functions "TestClass"
                                                                  "get"))
                   #'string<)))
     ;; then read in hash table
     (let ((table (make-hash-table :test #'equal)))
       (puthash (ac-ctags-make-top-level-hash-key test-ac-ctags-cpp-tagsfile3)
                (ac-ctags-read-in-hash-table test-ac-ctags-cpp-tagsfile3)
                table)
       (setq ac-ctags-top-level-hash-table table)
       (should
        (equal '("get()" "getInstance()" "getObj()" "getObj2()")
               (sort (mapcar #'substring-no-properties
                             (ac-ctags-cpp-collect-member-functions "TestClass"
                                                                    "get"))
                     #'string<)))))))

(ert-deftest test-ac-ctags-write-hash-table-then-read-in ()
  (test-ac-ctags-fixture
   (lambda ()
     ;; update tag file
     (shell-command (format "touch %s" test-ac-ctags-cpp-tagsfile3))
     (shell-command (format "touch %s" test-ac-ctags-cpp-stl-vector-tagfile))
     ;; this should create a new cache file
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile3 'new)
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-stl-vector-tagfile 'current)
     (should
      (equal '("get()" "getInstance()" "getObj()" "getObj2()")
             (sort (mapcar #'substring-no-properties
                           (ac-ctags-cpp-collect-member-functions "TestClass"
                                                                  "get"))
                   #'string<)))
     (should
      (equal '("push_back(bool __x)" "push_back(const value_type& __x)")
             (sort (mapcar #'substring-no-properties
                           (ac-ctags-cpp-collect-member-functions "std::vector"
                                                                  "push"))
                   #'string<)))
     (ac-ctags-reset)
     ;; then read in hash table
     (let ((table (make-hash-table :test #'equal)))
       (puthash (ac-ctags-make-top-level-hash-key test-ac-ctags-cpp-tagsfile3)
                (ac-ctags-read-in-hash-table test-ac-ctags-cpp-tagsfile3)
                table)
       (push test-ac-ctags-cpp-tagsfile3 ac-ctags-current-tags-list)
       (setq ac-ctags-top-level-hash-table table)
       (should
        (equal '("get()" "getInstance()" "getObj()" "getObj2()")
               (sort (mapcar #'substring-no-properties
                             (ac-ctags-cpp-collect-member-functions "TestClass"
                                                                    "get"))
                     #'string<)))))))

(ert-deftest test-ac-ctags-get-nodes-by-lang ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile2 'current)
     (should (= 2 (length (ac-ctags-get-node-tables-by-lang "C++"))))
     (should
      (every #'hash-table-p
             (ac-ctags-get-node-tables-by-lang "C++"))))))

(ert-deftest test-ac-ctags-get-nodes-by-lang-and-name ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'new)
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile2 'current)
     (should
      (equal '("get" "get" "getInstance" "getObj" "getObj2")
             (sort (mapcar #'ac-ctags-node-name
                           (ac-ctags-get-nodes-by-lang-and-name "C++" "get"))
                   #'string<))))))

(ert-deftest test-ac-ctags-unload-tag-file ()
  (test-ac-ctags-fixture
   (lambda ()
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile2 'new)
     (ac-ctags-visit-tags-file test-ac-ctags-cpp-tagsfile 'current)
     (should
      (equal (sort `(,test-ac-ctags-cpp-tagsfile ,test-ac-ctags-cpp-tagsfile2)
                   #'string<)
             (sort ac-ctags-current-tags-list
                   #'string<)))
     ;; this candidate comes from test-ac-ctags-cpp-tagsfile
     (should (equal
              '("getInstance()")
              (mapcar #'substring-no-properties
                      (ac-ctags-collect-candidates-by-lang "C++" "getIn"))))
     ;; then unload test-ac-ctags-cpp-tagsfile2
     (ac-ctags-unload-tag-file test-ac-ctags-cpp-tagsfile2)
     (should
      (equal `(,test-ac-ctags-cpp-tagsfile)
             ac-ctags-current-tags-list))
     (should-not
      ;; so no more candidate which begin with "getIn"
      (ac-ctags-collect-candidates-by-lang "C++" "getIn")))))

(ert-deftest test-ac-ctags-make-package-candidate ()
  (should
   (string= "java.lang"
            (ac-ctags-java-make-package-candidate "java.lang.String" "java.")))
  (should
   (string= "java.lang"
            (ac-ctags-java-make-package-candidate "java.lang" "java")))
  (should
   (string= "p1.p2.p3"
            (ac-ctags-java-make-package-candidate "p1.p2.p3.p4.p5" "p1.p2."))))