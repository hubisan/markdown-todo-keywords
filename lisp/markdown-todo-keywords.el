;;; markdown-todo-keywords.el --- Org-like TODO keywords for Markdown headings -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Daniel Hubmann <hubisan@gmail.com>
;; Maintainer: Daniel Hubmann <hubisan@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (markdown-mode "2.6"))
;; Keywords: markdown, outlines, convenience
;; URL: https://github.com/hubisan/markdown-todo-keywords

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; markdown-todo-keywords-mode adds Org-like TODO keywords to Markdown
;; headings while keeping the file valid, plain Markdown:
;;
;;   # TODO Write README
;;   ## NEXT Implement feature
;;   ## WAIT Review
;;   ## DONE Ship package
;;   ## CANCEL Drop idea
;;
;; The package provides keyword cycling, setting, clearing, jumping and
;; font-lock highlighting.  Keywords must be ALL CAPS.

;;; Code:

(require 'cl-lib)
(require 'markdown-mode)
(require 'subr-x)

;;;; Internal validation

(defun markdown-todo-keywords--valid-keyword-p (keyword)
  "Return non-nil if KEYWORD is a valid Markdown TODO keyword."
  (and (stringp keyword)
       (let ((case-fold-search nil))
         (string-match-p "\\`[A-Z][A-Z0-9_-]*\\'" keyword))))

(defun markdown-todo-keywords--valid-keyword-or-separator-p (keyword)
  "Return non-nil if KEYWORD is valid or the separator \"|\"."
  (or (string= keyword "|")
      (markdown-todo-keywords--valid-keyword-p keyword)))

(defun markdown-todo-keywords--validate-keyword-list (value)
  "Validate TODO keyword list VALUE."
  (let ((invalid (cl-remove-if #'markdown-todo-keywords--valid-keyword-or-separator-p
                               value)))
    (when invalid
      (user-error "Markdown TODO keywords must be ALL CAPS: %S" invalid))))

(defun markdown-todo-keywords--validate-face-list (value)
  "Validate TODO keyword face list VALUE."
  (let ((invalid
         (cl-remove-if
          (lambda (cell)
            (and (consp cell)
                 (markdown-todo-keywords--valid-keyword-p (car cell))))
          value)))
    (when invalid
      (user-error "Markdown TODO face keywords must be ALL CAPS: %S"
                  (mapcar (lambda (cell)
                            (if (consp cell) (car cell) cell))
                          invalid)))))

;;;; Customization

(defgroup markdown-todo-keywords nil
  "Org-like TODO keywords for Markdown headings."
  :group 'markdown
  :prefix "markdown-todo-keywords-")

(defface markdown-todo-keywords-default-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Default face for Markdown TODO keywords."
  :group 'markdown-todo-keywords)

(defcustom markdown-todo-keywords-list
  '("TODO" "NEXT" "WAIT" "|" "DONE" "CANCEL")
  "TODO keywords for Markdown headings.
Only ALL CAPS keywords are supported.  The separator \"|\" is
allowed in this list and ignored by the implementation."
  :type '(repeat string)
  :group 'markdown-todo-keywords
  :set (lambda (symbol value)
         (markdown-todo-keywords--validate-keyword-list value)
         (set-default symbol value)))

(defcustom markdown-todo-keywords-faces nil
  "Faces for specific Markdown TODO keywords.
This is a list of cons cells, with TODO keywords in the car and
faces in the cdr.  The face can be a symbol, a color as a string,
or a property list of attributes, like
  (:foreground \"blue\" :weight bold :underline t).
If it is a color string, the keyword inherits from
`markdown-todo-keywords-default-face' and uses the string as
foreground color."
  :type '(repeat
          (cons
           (string :tag "Keyword")
           (choice :tag "Face"
                   (string :tag "Color")
                   (sexp :tag "Face"))))
  :group 'markdown-todo-keywords
  :set (lambda (symbol value)
         (markdown-todo-keywords--validate-face-list value)
         (set-default symbol value)))

;;;; Internal helpers

(defun markdown-todo-keywords--keywords ()
  "Return configured TODO keywords without separator."
  (cl-remove-if (lambda (keyword) (string= keyword "|"))
                markdown-todo-keywords-list))

(defun markdown-todo-keywords--keyword-regexp ()
  "Return regexp matching configured TODO keywords."
  (regexp-opt (markdown-todo-keywords--keywords)))

(defun markdown-todo-keywords--regexp ()
  "Return regexp matching a TODO keyword after a Markdown heading marker."
  (concat "^\\(#+[ \t]+\\)"
          "\\("
          (markdown-todo-keywords--keyword-regexp)
          "\\)"
          "\\([ \t]+\\)"))

(defun markdown-todo-keywords--heading-regexp ()
  "Return regexp matching a Markdown ATX heading marker."
  "^\\(#+[ \t]+\\)")

(defun markdown-todo-keywords--any-heading-regexp ()
  "Return regexp matching Markdown ATX headings with optional TODO keyword."
  (concat "^\\(#+\\)[ \t]+"
          "\\(?:\\("
          (markdown-todo-keywords--keyword-regexp)
          "\\)[ \t]+\\)?"
          "\\(.*\\)$"))

(defun markdown-todo-keywords--goto-heading ()
  "Move point to the current Markdown heading and return non-nil if found."
  (condition-case nil
      (progn
        (unless (markdown-on-heading-p)
          (markdown-back-to-heading))
        (markdown-on-heading-p))
    (error nil)))

(defun markdown-todo-keywords--face (keyword)
  "Return face for TODO KEYWORD."
  (let ((face (cdr (assoc-string keyword markdown-todo-keywords-faces t))))
    (cond
     ((null face)
      'markdown-todo-keywords-default-face)
     ((symbolp face)
      face)
     ((stringp face)
      `(:inherit markdown-todo-keywords-default-face :foreground ,face))
     ((listp face)
      face)
     (t
      'markdown-todo-keywords-default-face))))

(defun markdown-todo-keywords--next (keyword)
  "Return next TODO keyword after KEYWORD."
  (let* ((keywords (markdown-todo-keywords--keywords))
         (pos (cl-position keyword keywords :test #'string=)))
    (if pos
        (nth (mod (1+ pos) (length keywords)) keywords)
      (car keywords))))

(defun markdown-todo-keywords--candidate-display (level keyword title)
  "Return completion display string for LEVEL, KEYWORD and TITLE."
  (format "%-10s %s %s"
          (or keyword "")
          (make-string level ?#)
          title))

(defun markdown-todo-keywords--heading-candidates ()
  "Return completion candidates for Markdown headings."
  (let (candidates)
    (save-excursion
      (goto-char (point-min))
      (let ((case-fold-search nil))
        (while (re-search-forward (markdown-todo-keywords--any-heading-regexp) nil t)
          (let* ((level (length (match-string-no-properties 1)))
                 (keyword (match-string-no-properties 2))
                 (title (string-trim (or (match-string-no-properties 3) "")))
                 (marker (copy-marker (match-beginning 0)))
                 (candidate (markdown-todo-keywords--candidate-display
                             level keyword title)))
            (put-text-property 0 (length candidate)
                               'markdown-todo-keywords-marker
                               marker candidate)
            (push candidate candidates)))))
    (nreverse candidates)))

;;;; Commands

;;;###autoload
(defun markdown-todo-keywords-current ()
  "Return TODO keyword at current Markdown heading, or nil."
  (save-excursion
    (when (markdown-todo-keywords--goto-heading)
      (let ((case-fold-search nil))
        (when (looking-at (markdown-todo-keywords--regexp))
          (match-string-no-properties 2))))))

;;;###autoload
(defun markdown-todo-keywords-set (keyword)
  "Set Markdown TODO KEYWORD on current heading."
  (interactive
   (list
    (completing-read "TODO: "
                     (markdown-todo-keywords--keywords)
                     nil t)))
  (unless (markdown-todo-keywords--valid-keyword-p keyword)
    (user-error "Markdown TODO keyword must be ALL CAPS: %s" keyword))
  (save-excursion
    (unless (markdown-todo-keywords--goto-heading)
      (user-error "Not on a Markdown heading"))
    (let ((case-fold-search nil))
      (cond
       ((looking-at (markdown-todo-keywords--regexp))
        (replace-match keyword t t nil 2))
       ((looking-at (markdown-todo-keywords--heading-regexp))
        (goto-char (match-end 1))
        (insert keyword " "))
       (t
        (user-error "Not on a Markdown heading")))))
  (font-lock-flush))

;;;###autoload
(defun markdown-todo-keywords-cycle ()
  "Cycle Markdown TODO keyword on current heading."
  (interactive)
  (let* ((current (markdown-todo-keywords-current))
         (next (markdown-todo-keywords--next current)))
    (markdown-todo-keywords-set next)))

;;;###autoload
(defun markdown-todo-keywords-clear ()
  "Remove Markdown TODO keyword from current heading."
  (interactive)
  (save-excursion
    (unless (markdown-todo-keywords--goto-heading)
      (user-error "Not on a Markdown heading"))
    (let ((case-fold-search nil))
      (when (looking-at (markdown-todo-keywords--regexp))
        (replace-match "\\1" t nil))))
  (font-lock-flush))

;;;###autoload
(defun markdown-todo-keywords-goto ()
  "Jump to a Markdown heading using completion.
Candidates include the TODO keyword, heading level and title, so
typing a keyword such as TODO, DONE or WAIT filters naturally with
standard completion UIs."
  (interactive)
  (let* ((candidates (markdown-todo-keywords--heading-candidates))
         (choice (completing-read "Heading: " candidates nil t))
         (marker (get-text-property 0 'markdown-todo-keywords-marker choice)))
    (unless marker
      (user-error "No heading selected"))
    (goto-char marker)
    (set-marker marker nil)
    (markdown-back-to-heading)))

;;;; Font lock

(defun markdown-todo-keywords--matcher (limit)
  "Search Markdown TODO keyword before LIMIT."
  (let ((case-fold-search nil))
    (re-search-forward (markdown-todo-keywords--regexp) limit t)))

(defconst markdown-todo-keywords--font-lock-keywords
  '((markdown-todo-keywords--matcher
     (2 (markdown-todo-keywords--face (match-string-no-properties 2))
        prepend)))
  "Font-lock keywords for `markdown-todo-keywords-mode'.")

(defun markdown-todo-keywords--enable ()
  "Enable Markdown TODO keyword fontification in current buffer."
  (font-lock-add-keywords nil markdown-todo-keywords--font-lock-keywords 'append)
  (font-lock-flush))

(defun markdown-todo-keywords--disable ()
  "Disable Markdown TODO keyword fontification in current buffer."
  (font-lock-remove-keywords nil markdown-todo-keywords--font-lock-keywords)
  (font-lock-flush))

;;;; Minor mode

;;;###autoload
(define-minor-mode markdown-todo-keywords-mode
  "Org-like TODO keywords for Markdown headings.
Supported syntax:
  # TODO Heading
  ## NEXT Heading
  ## WAIT Heading
  ## DONE Heading
  ## CANCEL Heading
Only ALL CAPS keywords are supported."
  :lighter " MdTODO"
  :group 'markdown-todo-keywords
  (if markdown-todo-keywords-mode
      (markdown-todo-keywords--enable)
    (markdown-todo-keywords--disable)))

(provide 'markdown-todo-keywords)

;;; markdown-todo-keywords.el ends here
