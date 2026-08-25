;;; gptel-commit-msg.el --- Use GPTel to generate commit messages from the current diff -*- lexical-binding: t -*-

;; Author: Votre Nom <email@example.com>
;; URL: https://github.com/fniessen/gptel-commit-msg
;; Package-Version: 0.1
;; Package-Requires: ((emacs "27.1") (gptel "0.1"))
;; Keywords: convenience, vc

;;; Commentary:

;; Generate Git commit messages from a diff buffer using GPTel.
;;
;; The current diff buffer, regardless of how the diff was produced (Magit, VC,
;; diff-mode, git diff output, etc.), is sent to the configured GPTel backend,
;; which returns a commit message describing the changes.
;;
;; The resulting message is displayed in a separate buffer and copied to
;; the kill ring.

;;; Code:

(require 'gptel)
(require 'subr-x)

(defconst gptel-commit-msg-buffer-name
  "*Commit Message*"
  "Buffer used to display generated commit messages.")

;;;###autoload
(defun gptel-commit-msg-generate ()
  "Generate a Git commit message from the current diff region or buffer.

The result is shown in `gptel-commit-msg-buffer-name' and copied
to the kill ring."
  (interactive)

  (unless (or (use-region-p)
              (> (buffer-size) 0))
    (user-error "[No content to analyze]"))

  (let* ((system-prompt
          "## 1. Role

You are an expert in writing Git commit messages.

Your mission is to write a clear and concise commit message that
describes the changes introduced by the provided diffs.

## 2. Tasks

- Carefully read each provided diff
- Write a commit message following Git best practices

## 3. Response format

- Subject only if it fully explains the change
- Body only if it adds useful detail (never repetition)
- Subject between 50 and 72 characters max, imperative style,
  capitalized, no period
- Separate subject and body with one blank line
- Body wrapped at 80 characters per line
- Never use backticks (`) to quote symbols, always use apostrophes (')

## 4. Points of attention

- Do not include the raw diffs in the response
- Do not add meta commentary or explanations
- Return only the commit message itself

## 5. Context

The supplied text contains one or more Git diffs:

")
         (diff-text
          (if (use-region-p)
              (buffer-substring-no-properties
               (region-beginning)
               (region-end))
            (buffer-substring-no-properties
             (point-min)
             (point-max)))))
    ;; Notify user that the process has started.
    (message "[Writing commit message...]")

    ;; Create and clear the buffer initially.
    (with-current-buffer
        (get-buffer-create gptel-commit-msg-buffer-name)
      (erase-buffer))

    ;; Send request without menu.
    (gptel-request
        diff-text
      :system system-prompt
      :callback
      (lambda (response info)
        (if (stringp response)
            (with-current-buffer
                (get-buffer-create gptel-commit-msg-buffer-name)
              (erase-buffer)

              (let ((msg (string-trim response)))
                ;; Strip Markdown fences.
                (setq msg
                      (replace-regexp-in-string
                       "\\````[^\n]*\n?"
                       ""
                       msg))

                (setq msg
                      (replace-regexp-in-string
                       "\n?```\\'"
                       ""
                       msg))

                ;; Use apostrophes instead of backticks.
                (setq msg
                      (replace-regexp-in-string "`" "'" msg))

                (kill-new msg)          ; Add to kill ring.
                (insert msg)

                (message
                 "[Commit message copied to kill ring.]"))

              (display-buffer
               (current-buffer)
               '((display-buffer-reuse-window
                  display-buffer-pop-up-window)
                 (inhibit-same-window . t))))

          (message
           "[Failed to generate commit message: %s]"
           (plist-get info :status)))))))

;;;###autoload
(with-eval-after-load 'diff-mode
  (define-key diff-mode-map
              (kbd "w")
              #'gptel-commit-msg-generate))

;;;###autoload
(global-set-key (kbd "C-x v w")
                #'gptel-commit-msg-generate)

(provide 'gptel-commit-msg)

;;; gptel-commit-msg.el ends here
