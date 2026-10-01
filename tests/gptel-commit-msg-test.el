;;; gptel-commit-msg-test.el --- Tests for gptel-commit-msg -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'gptel-commit-msg)

(defmacro gptel-commit-msg-test--with-mocks (&rest body)
  (declare (indent 0) (debug t))
  `(let ((gptel-backend (gptel--make-backend :name "Test"))
         (gptel-model 'test-model)
         (gptel-tools '(test-tool))
         captured-input
         captured-arguments
         captured-tools
         messages)
    (cl-letf (((symbol-function 'gptel-request)
                (lambda (input &rest arguments)
                  (setq captured-input input
                        captured-arguments arguments
                        captured-tools gptel-tools)))
               ((symbol-function 'message)
                (lambda (format-string &rest arguments)
                  (push (apply #'format format-string arguments) messages)))
               ((symbol-function 'display-buffer) (lambda (&rest _) nil))
               ((symbol-function 'other-window) (lambda (&rest _) nil)))
       ,@body)))

;; Empty input should be rejected before a request is started.
(ert-deftest gptel-commit-msg-rejects-empty-buffer ()
  (with-temp-buffer
    (should-error (gptel-commit-msg) :type 'user-error)))

;; The selected region is sent, and the active backend and model are reported.
(ert-deftest gptel-commit-msg-sends-region-and-reports-configuration ()
  (gptel-commit-msg-test--with-mocks
    (with-temp-buffer
      (insert "before DIFF after")
      (goto-char (point-min))
      (search-forward "DIFF")
      (let ((region-end (point))
            (transient-mark-mode t))
        (search-backward "DIFF")
        (set-mark region-end)
        (activate-mark)
        (gptel-commit-msg))
      (should (equal captured-input "DIFF"))
      (should (null captured-tools))
      (should (string-match-p
               "Test:test-model"
               (car messages))))))

;; The callback cleans the response and puts it in the buffer and kill ring.
(ert-deftest gptel-commit-msg-cleans-response-and-copies-it ()
  (let ((buffer-name "*gptel-commit-msg-test-result*")
        (gptel-commit-msg-buffer-name "*gptel-commit-msg-test-result*")
        (kill-ring nil)
        (kill-ring-yank-pointer nil))
    (unwind-protect
        (gptel-commit-msg-test--with-mocks
          (with-temp-buffer
            (insert "diff input")
            (gptel-commit-msg))
          (should (equal captured-input "diff input"))
          (funcall (plist-get captured-arguments :callback)
                   "```text\nUse `new` setting\n```"
                   nil)
          (should (equal (with-current-buffer buffer-name
                           (buffer-string))
                         "Use 'new' setting"))
          (should (equal (car kill-ring) "Use 'new' setting"))
          (should (equal (car messages)
                         "[Commit message copied to kill ring.]")))
      (when (get-buffer buffer-name)
        (kill-buffer buffer-name)))))

(provide 'gptel-commit-msg-test)

;;; gptel-commit-msg-test.el ends here
