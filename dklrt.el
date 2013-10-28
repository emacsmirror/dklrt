;;; dklrt.el --- Ledger Recurring Transactions.

;; Copyright: (c) David Keegan 2011-2013.
;; Licence: FSF GPLv3.
;; Author: David Keegan <dksw@eircom.net>
;; Version: 0.1
;; Package-Requires: ((ldg-mode "20130908.1357") (emacs "24.1"))
;; Keywords: ledger ledger-cli recurring periodic automatic
;; URL: https://github.com/davidkeegan/dklrt

;;; Commentary:

;; An add-on to ledger-mode which inserts recurring transactions to
;; the current file.

;;; Code:

(require 'dkmisc)

;;;###autoload
(defgroup dklrt nil
"Customisation of dklrt package (Ledger Recurring Transactions)."
 :tag "dklrt"
 :group 'dk)

(defcustom dklrt-SortAfterAppend nil
"Controls positioning of appended recurring transactions.
If non-nil, sort the ledger buffer after recurring transactions
have been appended. This ensures the recurring transactions are
positioned by date. Note: the positions of non-recurring
transactions will probably be affected."
 :tag "dklrt-SortAfterAppend"
 :type '(boolean))

(defcustom dklrt-PythonProgram "python"
"The Python interpreter to be run.
The default assumes python is on the PATH."
 :tag "dklrt-PythonProgram"
 :type '(string))

(defcustom dklrt-AppendBefore "1w"
"Controls when a recurring transaction is actually appended.
The value is a period do list format: <integer><y|m|d|w|h>. A
recurring transaction is appended when the current date/time is
greater than or equal to the configured transaction date minus
the specified period. If nil or empty, the recurring transaction
is appended without anticipation on or after the configured
transaction date."
 :tag "dklrt-AppendBefore"
 :type '(string))

(defcustom dklrt-LedgerFileSuffix "ldg"
"Suffix of Ledger File (excluding period)."
 :tag "dklrt-LedgerFileSuffix"
 :type '(string))

(defcustom dklrt-RecurringConfigFileSuffix "rec"
"Suffix of Recurring Transactions Config File (excluding period)."
 :tag "dklrt-RecurringConfigFileSuffix"
 :type '(string))

(defconst dklrt-PackageDirectory
 (if load-file-name
  (file-name-directory load-file-name)
  nil))

; Hard-coded alternative value for debug only.
(or dklrt-PackageDirectory 
 (setq dklrt-PackageDirectory "/opt/dk/emacs/dklrt-20131028.838/"))

;;;###autoload
(defun dklrt-SetCcKeys()
"Bind \C-cr to dklrt-AppendRecurring.
To invoke, add this function to ledger-mode-hook."
 (define-key (current-local-map) "\C-cr" 'dklrt-AppendRecurring))

;;;###autoload
(defun dklrt-AppendRecurringMaybe()
"Call dklrt_AppendRecurring(), but only if appropriate."
 (interactive)
 (if (dklrt-AppendRecurringOk) (dklrt-AppendRecurring)))

;;;###autoload
(defun dklrt-AppendRecurring()
"Appends recurring transactions to the current ledger buffer/file."
 (interactive)
 (dklrt-AppendRecurringOk t)

 (message "Appending recurring transactions...")
 (let*
  ((Lfn (buffer-file-name))
   (Cfn (dklrt-RecurringConfigFileName Lfn))
   (Pfn (expand-file-name "Recurring.py" dklrt-PackageDirectory))
   (Td (dkmisc-TimeApplyShift (dkmisc-DateToText)
    (or dklrt-AppendBefore "0h")))
   (Sc (format "%s %s %s %s %s" dklrt-PythonProgram Pfn Lfn Td Cfn)))

   (message "Invoking: \"%s\"..." Sc)
   (let*
    ((Fl (point-max))
     (So (shell-command-to-string Sc)))

    ; Check for error.
    (and (> (length So) 0) (error So))

    ; Sync buffer with (possibly) altered file.
    ; NB: Suppress mode reinitialisation to avoid infinite loop.
    (revert-buffer t t t)
    
    ; Transactions were appended?
    (if (> (point-max) Fl)
     (progn
      (if dklrt-SortAfterAppend
       (progn
        (message "Sorting buffer transactions by date...")
        (ledger-sort-buffer)))

      (message "Saving ledger buffer...") 
      (save-buffer))))))

;;;###autoload
(defun dklrt-AppendRecurringOk(&optional Throw)
"Return non nil if ok to append recurring transactions.
The current buffer must be unmodified, in ledger-mode, and a
Recurring Transactions Config File must exist for the current
file."
 (and
  (dklrt-IsLedgerMode Throw)
  (dklrt-NotRecurringConfigFile Throw)
  (dklrt-Unmodified Throw)
  (dklrt-LedgerFileExists Throw)
  (dklrt-RecurringConfigFileExists Throw)))

;;;###autoload
(defun dklrt-IsLedgerMode(&optional Throw)
 "True if current buffer is a ledger buffer."
 (let*
  ((Rv (equal mode-name "Ledger")))
 (and (not Rv) Throw
  (error "Current buffer is not in ledger mode!"))
  Rv))

(defun dklrt-NotRecurringConfigFile(&optional Throw)
 "True if current buffer is not a Recurring Config File."
 (let*
  ((Fne (file-name-extension (buffer-file-name)))
   (Rv (not (string= Fne dklrt-RecurringConfigFileSuffix))))

  (and (not Rv) Throw
   (error "Cannot append recurring transactions to Config File!"))
  Rv))

(defun dklrt-Unmodified(&optional Throw)
 "True if current buffer is unmodified."
 (let*
  ((Rv (not (buffer-modified-p))))
  (and (not Rv) Throw
   (error "Current buffer has changed! Please save it first!"))
  Rv))

(defun dklrt-LedgerFileExists(&optional Throw)
"Return t if the ledger file exists otherwise nil."
 (let*
  ((Lfn (buffer-file-name))
   (Rv (and Lfn (file-exists-p Lfn))))
  (and (not Rv) Throw
   (error "No such Ledger File: \"%s\"!" Lfn))
  Rv))

(defun dklrt-RecurringConfigFileExists(&optional Throw)
"Return t if the Recurring Config File exists, otherwise nil."
 (let*
  ((Lfn (buffer-file-name))
   (Cfn (dklrt-RecurringConfigFileName Lfn))
   (Rv (and Cfn (file-exists-p Cfn))))
  (and (not Rv) Throw
   (error "No such Recurring Config File: \"%s\"!" Cfn))
  Rv))

(defun dklrt-RecurringConfigFileName(LedgerFileName)
"Returns the corresponding recurring configuration file name.
 Removes the suffix (if any) and then appends the recurring
 suffix as per 'dklrt-RecurringConfigFileSuffix'."
 (concat (file-name-sans-extension LedgerFileName) "."
  dklrt-RecurringConfigFileSuffix))

(provide 'dklrt)
