;;; wrap-to-fill.el --- Make a fill-column wide space for editing
;;
;; Author: Lennart Borgman (lennart O borgman A gmail O com)
;; Created: 2009-08-12 Wed
;; Version:
;; Last-Updated: x
;; URL:
;; Keywords:
;; Compatibility:
;;
;; Features that might be required by this library:
;;
;;   None
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Change log:
;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Code:


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Wrapping

;;;###autoload
(defcustom wrap-to-fill-left-marg nil
  "Left margin handling for `wrap-to-fill-column-mode'.
Used by `wrap-to-fill-column-mode'. If nil then center the
display columns. Otherwise it should be a number which will be
the left margin."
  :type '(choice (const :tag "Center" nil)
                 (integer :tag "Left margin"))
  :group 'convenience)
(make-variable-buffer-local 'wrap-to-fill-left-marg)

(defvar wrap-to-fill-old-margins 0)
(make-variable-buffer-local 'wrap-to-fill-old-margins)
(put 'wrap-to-fill-old-margins 'permanent-local t)

;;;###autoload
(defcustom wrap-to-fill-left-marg-modes
  '(text-mode
    fundamental-mode)
  "Major modes where `wrap-to-fill-left-margin' may be nil."
  :type '(repeat command)
  :group 'convenience)


         ;;ThisisaVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryLongWord ThisisaVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryLongWord

(defun wrap-to-fill-wider ()
  "Increase `fill-column' with 10."
  (interactive)
  (setq fill-column (+ fill-column 10))
  (wrap-to-fill-set-values-in-buffer-windows))

(defun wrap-to-fill-narrower ()
  "Decrease `fill-column' with 10."
  (interactive)
  (setq fill-column (- fill-column 10))
  (wrap-to-fill-set-values-in-buffer-windows))

(defvar wrap-to-fill-column-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [(control ?c) right] 'wrap-to-fill-wider)
    (define-key map [(control ?c) left] 'wrap-to-fill-narrower)
    map))

;; Fix-me: make the `wrap-prefix' behavior an option or separate minor
;; mode.

;;;###autoload
(define-minor-mode wrap-to-fill-column-mode
  "Use `fill-column' display columns in buffer windows.
By default the display columns are centered, but see the option
`wrap-to-fill-left-marg'.

Note 1: When turning this on `visual-line-mode' is also turned on. This
is not reset when turning off this mode.

Note 2: The text property `wrap-prefix' is set by this mode to
indent continuation lines.

Key bindings added by this minor mode:

\\{wrap-to-fill-column-mode-map}"
  :lighter " WrapFill"
  :group 'convenience
  (wrap-to-fill-font-lock wrap-to-fill-column-mode)
  (if wrap-to-fill-column-mode
      (progn
        ;; Hooks
        (add-hook 'window-configuration-change-hook 'wrap-to-fill-set-values nil t)
        ;; Wrapping
        (if (fboundp 'visual-line-mode)
            (visual-line-mode 1)
          (longlines-mode 1))
        ;; Margins
        (setq wrap-to-fill-old-margins (cons left-margin-width right-margin-width))
        (wrap-to-fill-set-values-in-buffer-windows))
    ;; Hooks
    (remove-hook 'window-configuration-change-hook 'wrap-to-fill-set-values t)
    ;; Wrapping
    (if (fboundp 'visual-line-mode)
        (visual-line-mode -1)
      (longlines-mode -1))
    ;; Margins
    (setq left-margin-width (car wrap-to-fill-old-margins))
    (setq right-margin-width (cdr wrap-to-fill-old-margins))
    (setq wrap-to-fill-old-margins nil)
    (dolist (win (get-buffer-window-list (current-buffer)))
      (set-window-margins win left-margin-width right-margin-width))
    ;; Indentation
    (let ((here (point))
          (inhibit-field-text-motion t)
          beg-pos
          end-pos)
      (mumamo-with-buffer-prepared-for-jit-lock
       (save-restriction
         (widen)
         (goto-char (point-min))
         (while (< (point) (point-max))
           (setq beg-pos (point))
           (setq end-pos (line-end-position))
           (when (equal (get-text-property beg-pos 'wrap-prefix)
                        (get-text-property beg-pos 'wrap-to-fill-prefix))
             (remove-list-of-text-properties
              beg-pos end-pos
              '(wrap-prefix)))
           (forward-line))
         (remove-list-of-text-properties
          (point-min) (point-max)
          '(wrap-to-fill-prefix)))
       (goto-char here)))))
(put 'wrap-to-fill-column-mode 'permanent-local t)

;; Fix-me: There is a confusion between buffer and window margins
;; here. Also the doc says that left-margin-width and dito right may
;; be nil. However they seem to be 0 by default, but when displaying a
;; buffer in a window then window-margins returns (nil).

(defvar wrap-to-fill-timer nil)
(make-variable-buffer-local 'wrap-to-fill-timer)

(defun wrap-to-fill-set-values ()
  (when (timerp wrap-to-fill-timer)
    (cancel-timer wrap-to-fill-timer))
  (setq wrap-to-fill-timer
        (run-with-idle-timer 0 nil 'wrap-to-fill-set-values-in-timer (selected-window) (current-buffer))))
(put 'wrap-to-fill-set-values 'permanent-local-hook t)

(defun wrap-to-fill-set-values-in-timer (win buf)
  (when (and (window-live-p win) (buffer-live-p buf))
    (condition-case err
        (if (eq buf (window-buffer win))
          (with-current-buffer buf
            (when wrap-to-fill-column-mode
              (wrap-to-fill-set-values-in-window win)))
          (message "INT ERR wrap-to-fill-set-values: buf /= winbuf %s /= %s" buf (window-buffer win))
          )
      (error (message "ERROR wrap-to-fill-set-values: %s" (error-message-string err))))))

(defun wrap-to-fill-set-values-in-buffer-windows ()
  "Use `fill-column' display columns in buffer windows."
  (let ((buf-windows (get-buffer-window-list (current-buffer))))
    (dolist (win buf-windows)
      (if wrap-to-fill-column-mode
          (wrap-to-fill-set-values-in-window win)
        (set-window-buffer nil (current-buffer))))))

(defvar wrap-old-win-width nil)
(make-variable-buffer-local 'wrap-old-win-width)
;; Fix-me: compensate for left-margin-width etc
(defun wrap-to-fill-set-values-in-window (win)
  (with-current-buffer (window-buffer win)
    (when wrap-to-fill-column-mode
      (let* ((win-width (window-width win))
             (win-margs (window-margins win))
             (win-full (+ win-width
                          (or (car win-margs) 0)
                          (or (cdr win-margs) 0)))
             (extra-width (- win-full fill-column))
             (fill-left-marg (unless (memq major-mode wrap-to-fill-left-marg-modes)
                               (or (when (> left-margin-width 0) left-margin-width)
                                   wrap-to-fill-left-marg)))
             (left-marg (if fill-left-marg
                            fill-left-marg
                          (- (/ extra-width 2) 1)))
             ;; Fix-me: Why do I have to subtract 1 here...???
             (right-marg (- win-full fill-column left-marg 1))
             (need-update nil)
             )
        (when wrap-old-win-width
          (unless (= wrap-old-win-width win-width)
            ;;(message "-")
            ;;(message "win-width 0: %s => %s, win-full=%s, e=%s l/r=%s/%s %S %S %S" wrap-old-win-width win-width win-full extra-width left-marg right-marg (window-edges) (window-inside-edges) (window-margins))
           ))
        (setq wrap-old-win-width win-width)
        (unless (> left-marg 0) (setq left-marg 0))
        (unless (> right-marg 0) (setq right-marg 0))
        (unless nil;(= left-marg (or left-margin-width 0))
          (setq left-margin-width left-marg)
          (setq need-update t))
        (unless nil;(= right-marg (or right-margin-width 0))
          (setq right-margin-width right-marg)
          (setq need-update t))
        ;;(message "win-width a: %s => %s, win-full=%s, e=%s l/r=%s/%s %S %S %S" wrap-old-win-width win-width win-full extra-width left-margin-width right-margin-width (window-edges) (window-inside-edges) (window-margins))
        (when need-update
          ;;(set-window-buffer win (window-buffer win))
          ;;(run-with-idle-timer 0 nil 'set-window-buffer win (window-buffer win))
          (dolist (win (get-buffer-window-list (current-buffer)))
            ;; Fix-me: check window width...
            (set-window-margins win left-margin-width right-margin-width))
          ;;(message "win-width b: %s => %s, win-full=%s, e=%s l/r=%s/%s %S %S %S" wrap-old-win-width win-width win-full extra-width left-marg right-marg (window-edges) (window-inside-edges) (window-margins))
          )
        ))))

;; (add-hook 'post-command-hook 'my-win-post-command nil t)
;; (remove-hook 'post-command-hook 'my-win-post-command t)
(defun my-win-post-command ()
  (message "win-post-command: l/r=%s/%s %S %S %S" left-margin-width right-margin-width (window-edges) (window-inside-edges) (window-margins))
           )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Font lock

(defun wrap-to-fill-fontify (bound)
  (save-restriction
    (widen)
    (let ((this-bol (if (bolp) (point)
                      (1+ (line-end-position)))))
      (unless (< this-bol bound) (setq this-bol nil))
      (when this-bol
        (goto-char (+ this-bol 0)) ;; return pos
        (let ((beg-pos this-bol)
              (end-pos (line-end-position)))
          (when (equal (get-text-property beg-pos 'wrap-prefix)
                       (get-text-property beg-pos 'wrap-to-fill-prefix))
            (skip-chars-forward "[:blank:]")
            (setq ind-str (buffer-substring-no-properties beg-pos (point)))
            (mumamo-with-buffer-prepared-for-jit-lock
             (put-text-property beg-pos end-pos 'wrap-prefix ind-str)
             (put-text-property beg-pos end-pos 'wrap-to-fill-prefix ind-str)))))
      ;; Return empty range, we do not want fontification
      (when this-bol
        (set-match-data (list (point) (point)))
        t))))

(defun wrap-to-fill-font-lock (on)
  ;; See mlinks.el
  (let* ((add-or-remove (if on 'font-lock-add-keywords 'font-lock-remove-keywords))
         (fontify-fun 'wrap-to-fill-fontify)
         (args (list nil `(( ,fontify-fun ( 0 'font-lock-warning-face t ))))))
    (when fontify-fun
      (when on (setq args (append args (list t))))
      (apply add-or-remove args)
      (font-lock-mode -1)
      (font-lock-mode 1))))

(provide 'wrap-to-fill)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; wrap-to-fill.el ends here
