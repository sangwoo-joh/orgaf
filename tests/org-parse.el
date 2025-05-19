;; org-parse.el
(require 'org)

(if (or (null argv) (not (= (length argv) 1)))
    (progn
      (message "Usage: emacs --script org-parse.el <your org note>")
      (kill-emacs 1))
  (let ((filename (car argv)))
    (if (not (file-exists-p filename))
        (progn
          (message "'%s': no such file" filename)
          (kill-emacs 1)))
    (with-current-buffer (find-file-noselect filename)
      (print (org-element-parse-buffer))
      (kill-emacs 0))))
