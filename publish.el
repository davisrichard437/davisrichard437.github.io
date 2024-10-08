#!/usr/bin/env -S emacs -Q --script

;; publish.el - emacs script to publish website
;; Copyright (C) 2022 Richard Davis

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(require 'package)

(setq package-user-dir (expand-file-name "./.packages"))

(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
;; (add-to-list 'package-archives '("nongnu" . "https://elpa.nongnu.org/nongnu/"))
(add-to-list 'package-archives
             '("melpa-stable" . "https://stable.melpa.org/packages/"))

(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(dolist (pkg '(ox-rss htmlize))
  (unless (package-installed-p pkg)
    (package-install pkg)))

(require 'ob-lob)
(require 'ox-publish)
(require 'ox-rss)

(setq tld "richarddavis.xyz"
      user-full-name "Richard Davis"
      regen-files '("content/en/blog/index.org"
                    "content/en/blog/rss.org")
      org-html-htmlize-output-type 'css
      org-html-validation-link nil
      org-src-fontify-natively t
      org-html-postamble-format '(("en" "<p class=\"copyright\">© %a, %T</p>")))
;; (message org-html-postamble-format)

(org-babel-lob-ingest "./content/variables.org")

(defun my/get-string-from-file (file)
  "Return file content as string."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(defun my/org-rss-publish-to-rss (plist filename pub-dir)
  "Publish RSS with PLIST, only when FILENAME is 'rss.org'.
PUB-DIR is when the output will be placed."
  (when (equal "rss.org" (file-name-nondirectory filename))
    (org-rss-publish-to-rss plist filename pub-dir)))

(defun my/format-rss-feed (title list)
  "Generate RSS feed, as a string.
TITLE is the title of the RSS feed.  LIST is an internal
representation for the files to include, as returned by
`org-list-to-lisp'.  PROJECT is the current project."
  (concat "#+TITLE: " title "\n\n"
          (org-list-to-subtree list 1 '(:icount "" :istart ""))))

(defun my/format-rss-feed-entry (entry style project)
  "Format ENTRY for the RSS feed.
ENTRY is a file name.  STYLE is either 'list' or 'tree'.
PROJECT is the current project."
  (cond ((not (directory-name-p entry))
         (let* ((file (org-publish--expand-file-name entry project))
                (title (org-publish-find-title entry project))
                (date (format-time-string
                       "%Y-%m-%d"
                       (org-publish-find-date entry project)))
                (link (concat (file-name-sans-extension entry) ".html"))
                (text
                 (with-temp-buffer
                   (insert-file-contents file)
                   ; remove kewords and comments
                   ; remove everything after first heading
                   (shell-command-on-region
                    (point-min)
                    (point-max)
                    "sed -n -e '/^[[:space:]]*#/d' -e '1,/^*/p'"
                    nil
                    t)
                   ; remove first heading
                   (shell-command-on-region
                    (point-min)
                    (point-max)
                    "sed '/^\\*/d'"
                    nil
                    t)
                   (string-trim (buffer-string)))))
           (with-temp-buffer
             (org-mode) ; need to call `org-set-property'
             (insert (format "* [[file:%s][%s]]\n" file title))
             (org-set-property "RSS_PERMALINK" link)
             (org-set-property "RSS_TITLE" title)
             (org-set-property "PUBDATE" date)
             (goto-char (point-max))
             (insert text)
             (buffer-string))))
        ((eq style 'tree)
         ;; Return only last subdir.
         (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(defun my/format-sitemap (title list)
  "Generate sitemap, as a string.
TITLE is the title of the RSS feed.  LIST is an internal
representation for the files to include, as returned by
`org-list-to-lisp'."
  (concat "#+TITLE: " title "\n"
          "#+SUBTITLE: Blog\n"
          "#+AUTHOR: " user-full-name "\n"
          "#+SETUPFILE: ../../../common/theme-readtheorg.setup\n\n"
          "#+INCLUDE: ../../../common/header-en.org\n\n"
          "Subscribe to the RSS feed [[file:./rss.xml][here]]!\n\n"
          (org-list-to-subtree list 1 '(:icount "" :istart ""))
          "\n"))

(defun my/format-sitemap-entry (file style project)
  "Format ENTRY for the RSS feed.
FILE is a file name.  STYLE is either 'list' or 'tree'.
PROJECT is the current project."
  (let ((path (org-publish--expand-file-name file project))
        (title (org-publish-find-title file project))
        (date (format-time-string "%Y-%m-%d"
                                  (org-publish-find-date file project))))
    (format "- [[file:%s][%s (%s)]]\n"
            file
            title
            date)))

(setq org-publish-project-alist
      (list
       (list "davisrichard437.github.io"
             :recursive t
             :base-directory "./content"
             :publishing-directory "./public"
             :publishing-function #'org-html-publish-to-html
             :section-numbers nil
             ;; :with-author nil
             ;; :time-stamp-file nil
             )
       (list "davisrichard437.github.io:assets"
             :base-directory "./assets/"
             :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|woff2\\|ttf\\|ico\\|jpeg"
             :publishing-directory "./public"
             :recursive t
             :publishing-function #'org-publish-attachment)
       (list "davisrichard437.github.io:rss"
             :base-directory "./content/en/blog"
             :base-extension "org"
             :recursive nil
             :exclude (regexp-opt '("rss.org" "index.org" "404.org"))
             :publishing-function 'my/org-rss-publish-to-rss
             :publishing-directory "./public/en/blog"
             :rss-extension "xml"
             :html-link-use-abs-url t
             :html-link-org-files-as-html t
             :html-link-home (format "https://%s/en/blog/" tld)
             :auto-sitemap t
             :sitemap-filename "rss.org" ; write intermediate rss.org
             :sitemap-title "Richard Davis, Composer"
             :sitemap-style 'list
             :sitemap-sort-files 'anti-chronologically
             :sitemap-function #'my/format-rss-feed
             :sitemap-format-entry #'my/format-rss-feed-entry
             :time-stamp-file nil
             :with-creator nil
             :with-author nil
             :time-stamp-file nil)
       (list "davisrichard437.github.io:blog"
             :base-directory "./content/en/blog"
             :base-extension "org"
             :publishing-directory "./public/en/blog"
             :publishing-function #'org-html-publish-to-html
             :recursive nil
             :exclude (regexp-opt '("rss.org"))
             :html-link-use-abs-url t
             :html-link-org-files-as-html t
             :auto-sitemap t
             :sitemap-filename "index.org"
             :sitemap-title "Richard Davis, Composer"
             :sitemap-style 'list
             :sitemap-format-entry #'my/format-sitemap-entry
             :sitemap-function #'my/format-sitemap
             :sitemap-sort-files 'anti-chronologically
             :sitemap-file-entry-format "%t (%d)"
             :html-postamble-format '((en "<div class=\"craftering\">
  <a href=\"https://craftering.systemcrafters.net/@davisrichard437/previous\">←</a>
  <a href=\"https://craftering.systemcrafters.net/\">craftering</a>
  <a href=\"https://craftering.systemcrafters.net/@davisrichard437/next\">→</a>
</div>
<div class=\"org-center\">
  <p class=\"copyright\">© %a, %T</p>
</div>"))
             ;; :with-author nil
             ;; :time-stamp-file nil
             )))

(setq org-safe-remote-resources
      '("\\`https://fniessen\\.github\\.io/org-html-themes/org/theme-readtheorg\\.setup\\'"))

(delete-directory "./public" t)
(dolist (f regen-files)
  (delete-file f))
(mkdir "./public")
(message (format "Publishing site via org version %s" org-version))
(org-publish-all t)

(message "Build complete!")
