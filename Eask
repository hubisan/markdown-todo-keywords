; -*- mode: emacs-lisp; lexical-binding: t -*-

(eval-when-compile
  (defvar sentence-end-double-space)
  (defvar checkdoc-verb-check-experimental-flag))

;; Domain Specific Language
;; https://emacs-eask.github.io/DSL/
(package "markdown-todo-keywords"
         "0.3.0"
         "Org-like TODO keywords for Markdown headings")

(website-url "https://github.com/hubisan/markdown-todo-keywords")
(keywords "markdown" "outlines" "convenience")
(license "GPLv3")

(package-file "lisp/markdown-todo-keywords.el")
(files "lisp/*.el")

(load-paths "./lisp/" "./tests/")

;; https://emacs-eask.github.io/DSL/#-source-alias
(source "gnu")
(source "nongnu")
(source "melpa")

;; https://emacs-eask.github.io/DSL/#-depends-on-package-name-rest-recipe
(depends-on "emacs" "29.4")
(depends-on "markdown-mode" "2.6")

;; https://emacs-eask.github.io/DSL/#-development-rest-body
(development
 (depends-on "buttercup")
 (depends-on "with-simulated-input"))

;; Tell checkdoc not to demand two spaces after a period.
(setq sentence-end-double-space nil)

;; Don't check docstring for correct verb use.
(setq checkdoc-verb-check-experimental-flag nil)
