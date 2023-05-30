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

(require 'ox-publish)
(require 'ob-lob)

(org-babel-lob-ingest "./content/variables.org")

(defvar yt-iframe-format
  (concat "<div class=\"video\">"
          "  <iframe src=\"https://www.youtube-nocookie.com/embed/%s\" allowfullscreen></iframe>"
          "</div>"))

(defun my/embed-video (video-id)
  (format yt-iframe-format video-id))

(org-link-set-parameters
 "yt"
 :follow
 (lambda (handle)
   (browse-url
    (concat "https://www.youtube.com/watch?v="
            handle)))
 :export
 (lambda (path desc backend channel)
   (when (eq backend 'html)
     (my/embed-video path))))

(setq org-publish-project-alist
      (list
       (list "davisrichard437.github.io"
             :recursive t
             :base-directory "./content"
             :publishing-directory "./public"
             :publishing-function #'org-html-publish-to-html
             :section-numbers nil)))

(setq org-safe-remote-resources
      '("\\`https://fniessen\\.github\\.io/org-html-themes/org/theme-readtheorg\\.setup\\'"))

(delete-directory "./public" t)
(mkdir "./public")
(org-publish-all t)

(message "Build complete!")