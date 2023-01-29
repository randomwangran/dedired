;;; dedired.el --- Simple directory with an efficient file-naming scheme -*- lexical-binding: t -*-

;; Copyright (C) 2022-2023

;; Author: Ran Wang
;; Maintainer: Ran Wang
;; URL: 
;; Mailing-List: 
;; Version: 0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0
;; Package-Requires: ((emacs "28.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Dedired aims to be a simple-to-use, focused-in-scope, and effective
;; directory tool for Emacs. 


(defvar denote-excluded-punctuation-extra-regexp nil
  "Additional punctuation that is removed from file names.
This variable is for advanced users who need to extend the
`denote-excluded-punctuation-regexp'.  Once we have a better
understanding of what we should be omitting, we will update
things accordingly.")

(defconst denote-id-format "%Y%m%dT%H%M%S"
  "Format of ID prefix of a note's filename.
The note's ID is derived from the date and time of its creation.")

(defconst denote-excluded-punctuation-regexp "[][{}!@#$%^&*()=+'\"?,.\|;:~`‘’“”/]*"
  "Punctionation that is removed from file names.
We consider those characters illegal for our purposes.")

(defconst denote-id-regexp "\\([0-9]\\{8\\}\\)\\(T[0-9]\\{6\\}\\)"
  "Regular expression to match `denote-id-format'.")

(defconst denote-keywords-regexp "__\\([[:alnum:][:nonascii:]_-]*\\)"
  "Regular expression to match the KEYWORDS field in a file name.")

(defcustom denote-excluded-directories-regexp nil
  "Regular expression of directories to exclude from all operations.
Omit matching directories from file prompts and also exclude them
from all functions that check the contents of the variable
`denote-directory'.  The regexp needs to match only the name of
the directory, not its full path.

File prompts are used by several commands, such as `denote-link'
and `denote-subdirectory'.

Functions that check for files include `denote-directory-files'
and `denote-directory-subdirectories'.

The match is performed with `string-match-p'."
  :group 'denote
  :package-version '(denote . "1.2.0")
  :type 'string)

(defcustom denote-allow-multi-word-keywords t
  "If non-nil keywords can consist of multiple words.
Words are automatically separated by a hyphen when using the
`denote' command or related.  The hyphen is the only legal
character---no spaces, no other characters.  If, for example, the
user types <word1_word2> or <word1 word2>, it is converted to
<word1-word2>.

When nil, do not allow keywords to consist of multiple words.
Reduce them to a single word, such as by turning <word1_word2> or
<word1 word2> into <word1word2>."
  :group 'denote
  :package-version '(denote . "0.1.0")
  :type 'boolean)

(defcustom denote-prompts '(title keywords)
  "Specify the prompts of the `denote' command for interactive use.

The value is a list of symbols, which includes any of the following:

- `title': Prompt for the title of the new note.

- `keywords': Prompts with completion for the keywords of the new
  note.  Available candidates are those specified in the user
  option `denote-known-keywords'.  If the user option
  `denote-infer-keywords' is non-nil, keywords in existing note
  file names are included in the list of candidates.  The
  `keywords' prompt uses `completing-read-multiple', meaning that
  it can accept multiple keywords separated by a comma (or
  whatever the value of `crm-separator' is).

- `file-type': Prompts with completion for the file type of the
  new note.  Available candidates are those specified in the user
  option `denote-file-type'.  Without this prompt, `denote' uses
  the value of `denote-file-type'.

- `subdirectory': Prompts with completion for a subdirectory in
  which to create the note.  Available candidates are the value
  of the user option `denote-directory' and all of its
  subdirectories.  Any subdirectory must already exist: Denote
  will not create it.

- `date': Prompts for the date of the new note.  It will expect
  an input like 2022-06-16 or a date plus time: 2022-06-16 14:30.
  Without the `date' prompt, the `denote' command uses the
  `current-time'.  (To leverage the more sophisticated Org
  method, see the `denote-date-prompt-use-org-read-date'.)

- `template': Prompts for a KEY among `denote-templates'.  The
  value of that KEY is used to populate the new note with
  content, which is added after the front matter.

The prompts occur in the given order.

If the value of this user option is nil, no prompts are used.
The resulting file name will consist of an identifier (i.e. the
date and time) and a supported file type extension (per
`denote-file-type').

Recall that Denote's standard file-naming scheme is defined as
follows (read the manual for the technicalities):

    DATE--TITLE__KEYWORDS.EXT

If either or both of the `title' and `keywords' prompts are not
included in the value of this variable, file names will be any of
those permutations:

    DATE.EXT
    DATE--TITLE.EXT
    DATE__KEYWORDS.EXT

When in doubt, always include the `title' and `keywords' prompts.

Finally, this user option only affects the interactive use of the
`denote' command (advanced users can call it from Lisp).  For
ad-hoc interactive actions that do not change the default
behaviour of the `denote' command, users can invoke these
convenience commands: `denote-type', `denote-subdirectory',
`denote-date', `denote-template'."
  :group 'denote
  :package-version '(denote . "0.5.0")
  :link '(info-link "(denote) The denote-prompts option")
  :type '(radio (const :tag "Use no prompts" nil)
                (set :tag "Available prompts" :greedy t
                     (const :tag "Title" title)
                     (const :tag "Keywords" keywords)
                     (const :tag "Date" date)
                     (const :tag "File type extension" file-type)
                     (const :tag "Subdirectory" subdirectory)
                     (const :tag "Template" template))))

(defun denote-keywords-sort (keywords)
  "Sort KEYWORDS if `denote-sort-keywords' is non-nil.
KEYWORDS is a list of strings, per `denote-keywords-prompt'."
  (if denote-sort-keywords
      (sort keywords #'string-lessp)
    keywords))

(defun denote-keywords-prompt ()
  "Prompt for one or more keywords.
In the case of multiple entries, those are separated by the
`crm-sepator', which typically is a comma.  In such a case, the
output is sorted with `string-lessp'.

Process the return value with `denote-keywords-sort'."
  (denote-keywords-sort (denote--keywords-crm (denote-keywords))))

(defun denote-title-prompt (&optional default-title)
  "Read file title for `denote'.
With optional DEFAULT-TITLE use it as the default value."
  (let* ((def default-title)
         (format (if (and def (not (string-empty-p def)))
                     (format "File title [%s]: " def)
                   "File title: ")))
    (read-string format nil 'denote--title-history def)))

(defun denote--keywords-crm (keywords &optional prompt)
  "Use `completing-read-multiple' for KEYWORDS.
With optional PROMPT, use it instead of a generic text for file
keywords."
  (delete-dups
   (completing-read-multiple
    (or prompt "File keyword: ") keywords
    nil nil nil 'denote--keyword-history)))

(defun denote-keywords ()
  "Return appropriate list of keyword candidates.
If `denote-infer-keywords' is non-nil, infer keywords from
existing notes and combine them into a list with
`denote-known-keywords'.  Else use only the latter.

Inferred keywords are filtered by the user option
`denote-excluded-keywords-regexp'."
  (delete-dups
   (if denote-infer-keywords
       (append (denote--inferred-keywords) denote-known-keywords)
     denote-known-keywords)))

(defun denote--inferred-keywords ()
  "Extract keywords from `denote-directory-files'.
This function returns duplicates.  The `denote-keywords' is the
one that doesn't."
  (let ((kw (mapcan #'denote-extract-keywords-from-path (denote-directory-files))))
    (if-let ((regexp denote-excluded-keywords-regexp))
        (seq-filter (lambda (k) (not (string-match-p regexp k))) kw)
      kw)))

(defcustom denote-directory "/Your/PATH/"
  "Directory for storing personal notes.

A safe local value of either `default-directory' or `local' can
be added as a value in a .dir-local.el file.  Do this if you
intend to use multiple directory silos for your notes while still
relying on a global value (which is the value of this variable).
The Denote manual has a sample (search for '.dir-locals.el').
Those silos do not communicate with each other: they remain
separate.

The local value influences where commands such as `denote' will
place the newly created note.  If the command is called from a
directory or file where the local value exists, then that value
take precedence, otherwise the global value is used.

If you intend to reference this variable in Lisp, consider using
the function `denote-directory' instead: it returns the path as a
directory and also checks if a safe local value should be used."
  :group 'denote
  :safe (lambda (val) (or (eq val 'local) (eq val 'default-directory)))
  :package-version '(denote . "0.5.0")
  :link '(info-link "(denote) Maintain separate directories for notes")
  :type 'directory)

(defun denote-directory-files ()
  "Return list of absolute file paths in variable `denote-directory'.

Files only need to have an identifier.  The return value may thus
include file types that are not implied by `denote-file-type'.
To limit the return value to text files, use the function
`denote-directory-text-only-files'.

Remember that the variable `denote-directory' accepts a dir-local
value, as explained in its doc string."
  (mapcar
   #'expand-file-name
   (seq-remove
    (lambda (f)
      (not (denote-file-has-identifier-p f)))
    (directory-files-recursively
     (denote-directory)
     directory-files-no-dot-files-regexp
     :include-directories
     (lambda (f)
       (cond
        ((when-let ((regexp denote-excluded-directories-regexp))
           (not (string-match-p regexp f))))
        ((file-readable-p f))
        (t)))
     :follow-symlinks))))

(defcustom denote-known-keywords
  '("fist" "emacs" "philosophy" "politics" "economics")
  "List of strings with predefined keywords for `denote'.
Also see user options: `denote-allow-multi-word-keywords',
`denote-infer-keywords', `denote-sort-keywords'."
  :group 'denote
  :package-version '(denote . "0.1.0")
  :type '(repeat string))

(defcustom denote-infer-keywords t
  "Whether to infer keywords from existing notes' file names.

When non-nil, search the file names of existing notes in the
variable `denote-directory' for their keyword field and extract
the entries as \"inferred keywords\".  These are combined with
`denote-known-keywords' and are presented as completion
candidates while using `denote' and related commands
interactively.

If nil, refrain from inferring keywords.  The aforementioned
completion prompt only shows the `denote-known-keywords'.  Use
this if you want to enforce a restricted vocabulary.

The user option `denote-excluded-keywords-regexp' can be used to
exclude keywords that match a regular expression.

Inferred keywords are specific to the value of the variable
`denote-directory'.  If a silo with a local value is used, as
explained in that variable's doc string, the inferred keywords
are specific to the given silo.

For advanced Lisp usage, the function `denote-keywords' returns
the appropriate list of strings."
  :group 'denote
  :package-version '(denote . "0.1.0")
  :type 'boolean)

(defun denote-directory ()
  "Return path of variable `denote-directory' as a proper directory."
  (let* ((val (or (buffer-local-value 'denote-directory (current-buffer))
                  denote-directory))
         (path (if (or (eq val 'default-directory) (eq val 'local)) default-directory val)))
    (unless (file-directory-p path)
      (make-directory path t))
    (file-name-as-directory (expand-file-name path))))

(defun denote--inferred-keywords ()
  "Extract keywords from `denote-directory-files'.
This function returns duplicates.  The `denote-keywords' is the
one that doesn't."
  (let ((kw (mapcan #'denote-extract-keywords-from-path (denote-directory-files))))
    (if-let ((regexp denote-excluded-keywords-regexp))
        (seq-filter (lambda (k) (not (string-match-p regexp k))) kw)
      kw)))

(defcustom denote-excluded-keywords-regexp nil
  "Regular expression of keywords to not infer.
Keywords are inferred from file names and provided at relevant
prompts as completion candidates when the user option
`denote-infer-keywords' is non-nil.

The match is performed with `string-match-p'."
  :group 'denote
  :package-version '(denote . "1.2.0")
  :type 'string)

(defun denote-keywords-sort (keywords)
  "Sort KEYWORDS if `denote-sort-keywords' is non-nil.
KEYWORDS is a list of strings, per `denote-keywords-prompt'."
  (if denote-sort-keywords
      (sort keywords #'string-lessp)
    keywords))

(defcustom denote-sort-keywords t
  "Whether to sort keywords in new files.

When non-nil, the keywords of `denote' are sorted with
`string-lessp' regardless of the order they were inserted at the
minibuffer prompt.

If nil, show the keywords in their given order."
  :group 'denote
  :package-version '(denote . "0.1.0")
  :type 'boolean)

(defun denote-date-prompt ()
  "Prompt for date, expecting YYYY-MM-DD or that plus HH:MM.
Use Org's more advanced date selection utility if the user option
`denote-date-prompt-use-org-read-date' is non-nil."
  (if (and denote-date-prompt-use-org-read-date
           (require 'org nil :no-error))
      (let* ((time (org-read-date nil t))
             (org-time-seconds (format-time-string "%S" time))
             (cur-time-seconds (format-time-string "%S" (current-time))))
        ;; When the user does not input a time, org-read-date defaults to 00 for seconds.
        ;; When the seconds are 00, we add the current seconds to avoid identifier collisions.
        (when (string-equal "00" org-time-seconds)
          (setq time (time-add time (string-to-number cur-time-seconds))))
        (format-time-string "%Y-%m-%d %H:%M:%S" time))
    (read-string
     "DATE and TIME for note (e.g. 2022-06-16 14:30): "
     nil 'denote--date-history)))

(defun denote--dir-in-denote-directory-p (directory)
  "Return DIRECTORY if in variable `denote-directory', else nil."
  (when (and directory
             (string-prefix-p (denote-directory)
                              (expand-file-name directory)))
    directory))

(defun denote-format-file-name (path id keywords title-slug)
  "Format file name.
PATH, ID, KEYWORDS, TITLE-SLUG are expected to be supplied by
`denote' or equivalent: they will all be converted into a single
string.  EXTENSION is the file type extension, as a string."
  (let ((kws (denote--keywords-combine keywords))
        (file-name (concat path id)))
    (when (and title-slug (not (string-empty-p title-slug)))
      (setq file-name (concat file-name "--" title-slug)))
    (when (and keywords (not (string-blank-p kws)))
      (setq file-name (concat file-name "__" kws)))))

(defun denote--path (title keywords dir id)
  "Return path to new file with ID, TITLE, KEYWORDS and FILE-TYPE in DIR."
  (denote-format-file-name
   dir id
   (denote-sluggify-keywords keywords)
   (denote-sluggify title)))

(defun denote--prepare-directory (title keywords id directory)
  "Prepare a new note file.

Arguments TITLE, KEYWORDS, DATE, ID, DIRECTORY, FILE-TYPE,
and TEMPLATE should be valid for note creation."
  (let ((path (denote--path title keywords directory id)))
    (make-directory path)
    (dired path)))

(defun denote--keywords-combine (keywords)
  "Format KEYWORDS output of `denote-keywords-prompt'."
  (mapconcat #'downcase keywords "_"))

(defun denote-sluggify-keywords (keywords)
  "Sluggify KEYWORDS, which is a list of strings."
  (mapcar (if denote-allow-multi-word-keywords
              #'denote-sluggify
            #'denote-sluggify-and-join)
          keywords))

(defun denote-sluggify (str)
  "Make STR an appropriate slug for file names and related."
  (downcase (denote--slug-hyphenate (denote--slug-no-punct str))))

(defun denote--slug-no-punct (str)
  "Convert STR to a file name slug."
  (replace-regexp-in-string
   (concat denote-excluded-punctuation-regexp
           denote-excluded-punctuation-extra-regexp)
   "" str))

(defun denote--slug-hyphenate (str)
  "Replace spaces and underscores with hyphens in STR.
Also replace multiple hyphens with a single one and remove any
leading and trailing hyphen."
  (replace-regexp-in-string
   "^-\\|-$" ""
   (replace-regexp-in-string
    "-\\{2,\\}" "-"
    (replace-regexp-in-string "_\\|\s+" "-" str))))

(defun denote-file-has-identifier-p (file)
  "Return non-nil if FILE has a Denote identifier."
  (when file
    (string-match-p (concat "\\`" denote-id-regexp)
                    (file-name-nondirectory file))))

(defun denote-extract-keywords-from-path (path)
  "Extract keywords from PATH and return them as a list of strings.
PATH must be a Denote-style file name where keywords are prefixed
with an underscore.

If PATH has no such keywords, return nil."
  (let* ((file-name (file-name-nondirectory path))
         (kws (when (string-match denote-keywords-regexp file-name)
                (match-string-no-properties 1 file-name))))
    (when kws
      (split-string kws "_"))))

(defun dedired (&optional title keywords file-type subdirectory date template)
  (interactive
   (let ((args (make-vector 6 nil)))
     (dolist (prompt denote-prompts)
       (pcase prompt
         ('title (aset args 0 (denote-title-prompt
                               (when (use-region-p)
                                 (buffer-substring-no-properties
                                  (region-beginning)
                                  (region-end))))))
         ('keywords (aset args 1 (denote-keywords-prompt)))
         ;;  ('file-type (aset args 2 (denote-file-type-prompt)))
         ;;  ('subdirectory (aset args 3 (denote-subdirectory-prompt)))
         
         ('date (aset args 4 (denote-date-prompt)))
         ;;  ('template (aset args 5 (denote-template-prompt)))
         ))
     (append args nil)))

  (let* ((title (or title ""))
         ;;  (file-type (denote--valid-file-type (or file-type denote-file-type)))
         (kws (if (called-interactively-p 'interactive)
                  keywords
                (denote-keywords-sort keywords)))
         (date (if (or (null date) (string-empty-p date))
                   (current-time)
                 (denote--valid-date date)))
         (id (format-time-string denote-id-format date))
         (directory (if (denote--dir-in-denote-directory-p subdirectory)
                        (file-name-as-directory subdirectory)
                      (denote-directory))))
    ;;  (message "%s %s %s %s" title kws id directory)
    (denote--prepare-directory title kws id directory)
    ;;  (denote--keywords-add-to-history keywords)
    ))
