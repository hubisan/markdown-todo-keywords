;;; markdown-todo-keywords-test.el --- Tests for markdown-todo-keywords -*- lexical-binding: t; -*-

(require 'buttercup)
(require 'markdown-mode)
(require 'markdown-todo-keywords)

(defmacro markdown-todo-keywords-test-with-buffer (content &rest body)
  "Create a temporary Markdown buffer with CONTENT and run BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,content)
     (markdown-mode)
     (markdown-todo-keywords-mode 1)
     (goto-char (point-min))
     ,@body))

(describe "markdown-todo-keywords validation"
  (it "accepts ALL CAPS keywords"
    (expect (markdown-todo-keywords--valid-keyword-p "TODO") :to-be-truthy)
    (expect (markdown-todo-keywords--valid-keyword-p "NEXT") :to-be-truthy)
    (expect (markdown-todo-keywords--valid-keyword-p "WAIT_1") :to-be-truthy)
    (expect (markdown-todo-keywords--valid-keyword-p "DONE-1") :to-be-truthy))

  (it "rejects non ALL CAPS keywords"
    (expect (markdown-todo-keywords--valid-keyword-p "todo") :to-be nil)
    (expect (markdown-todo-keywords--valid-keyword-p "Todo") :to-be nil)
    (expect (markdown-todo-keywords--valid-keyword-p "TODO next") :to-be nil)
    (expect (markdown-todo-keywords--valid-keyword-p "|") :to-be nil))

  (it "accepts separator in keyword list"
    (expect (markdown-todo-keywords--valid-keyword-or-separator-p "|")
            :to-be-truthy))

  (it "removes separator from effective keywords"
    (let ((markdown-todo-keywords-list '("TODO" "NEXT" "|" "DONE")))
      (expect (markdown-todo-keywords--keywords)
              :to-equal '("TODO" "NEXT" "DONE")))))

(describe "markdown-todo-keywords commands"
  (it "detects current keyword"
    (markdown-todo-keywords-test-with-buffer "# TODO Write README\n"
      (expect (markdown-todo-keywords-current) :to-equal "TODO")))

  (it "returns nil when heading has no keyword"
    (markdown-todo-keywords-test-with-buffer "# Write README\n"
      (expect (markdown-todo-keywords-current) :to-be nil)))

  (it "sets keyword on heading without keyword"
    (markdown-todo-keywords-test-with-buffer "# Write README\n"
      (markdown-todo-keywords-set "TODO")
      (expect (buffer-string) :to-equal "# TODO Write README\n")))

  (it "replaces existing keyword"
    (markdown-todo-keywords-test-with-buffer "# TODO Write README\n"
      (markdown-todo-keywords-set "DONE")
      (expect (buffer-string) :to-equal "# DONE Write README\n")))

  (it "cycles through configured keywords"
    (let ((markdown-todo-keywords-list
           '("TODO" "NEXT" "WAIT" "|" "DONE" "CANCEL")))
      (markdown-todo-keywords-test-with-buffer "# TODO Write README\n"
        (markdown-todo-keywords-cycle)
        (expect (buffer-string) :to-equal "# NEXT Write README\n")
        (markdown-todo-keywords-cycle)
        (expect (buffer-string) :to-equal "# WAIT Write README\n")
        (markdown-todo-keywords-cycle)
        (expect (buffer-string) :to-equal "# DONE Write README\n")
        (markdown-todo-keywords-cycle)
        (expect (buffer-string) :to-equal "# CANCEL Write README\n")
        (markdown-todo-keywords-cycle)
        (expect (buffer-string) :to-equal "# TODO Write README\n"))))

  (it "inserts first keyword when cycling heading without keyword"
    (let ((markdown-todo-keywords-list '("TODO" "NEXT" "|" "DONE")))
      (markdown-todo-keywords-test-with-buffer "# Write README\n"
        (markdown-todo-keywords-cycle)
        (expect (buffer-string) :to-equal "# TODO Write README\n"))))

  (it "clears keyword"
    (markdown-todo-keywords-test-with-buffer "# TODO Write README\n"
      (markdown-todo-keywords-clear)
      (expect (buffer-string) :to-equal "# Write README\n")))

  (it "signals error when setting invalid keyword"
    (markdown-todo-keywords-test-with-buffer "# Write README\n"
      (expect (markdown-todo-keywords-set "todo") :to-throw))))

(describe "markdown-todo-keywords completion candidates"
  (it "creates heading candidates with keyword, level and title"
    (markdown-todo-keywords-test-with-buffer
        "# TODO Write README\n## DONE Publish package\n### Plain Heading\n"
      (let ((candidates (markdown-todo-keywords--heading-candidates)))
        (expect (length candidates) :to-equal 3)
        (expect (nth 0 candidates) :to-match "TODO")
        (expect (nth 0 candidates) :to-match "# Write README")
        (expect (nth 1 candidates) :to-match "DONE")
        (expect (nth 1 candidates) :to-match "## Publish package")
        (expect (nth 2 candidates) :to-match "### Plain Heading")
        (expect (get-text-property 0 'markdown-todo-keywords-marker
                                   (car candidates))
                :to-be-truthy)))))
