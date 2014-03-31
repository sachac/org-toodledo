(require 'org-toodledo-sim)

(defvar org-toodledo-test-stop-on-error nil
  "Set to t to stop tests on first error.  Useful to leave buffers
in the same state as when the test fails.")

;;
;; Run org-toodledo-tests
;;
(defun org-toodledo-test (&rest tests)
  "Org-toodledo tests"
  (interactive)

  (save-excursion
    (setq org-toodledo-log-level 3)
    (set-buffer (get-buffer-create "*Org-toodledo-log*"))
    (erase-buffer)
    (exec-cmd "rm -rf /tmp/org-toodledo-test*")

    (let ((org-toodledo-test-count 0)
          (org-toodledo-test-pass 0)
          (org-toodledo-test-fail 0)
          (debug-on-error t)
          (org-toodledo-test-msg-buf
           (get-buffer-create "*Org-toodledo-test-log*"))
          (org-toodledo-sync-message-time 0)
          (org-toodledo-sync-new-completed-tasks nil)
          (buf1-file (make-temp-file "/tmp/org-toodledo-test-1-"))
          (buf2-file (make-temp-file "/tmp/org-toodledo-test-2-"))
          )

      (setq org-toodledo-test-mode t)
      (setq org-toodledo-sim-mode nil)
      (pop-to-buffer org-toodledo-test-msg-buf)
      (erase-buffer)

      (when (null tests)
        (org-toodledo-test-cleanup))

      (org-toodledo-test-message "Starting tests")

      (let ((buf1 (get-buffer-create buf1-file))
            (buf2 (get-buffer-create buf2-file)))

        (set-buffer buf1)
        (write-file buf1-file)

        (set-buffer buf2)
        (write-file buf2-file)

        (when (or (member 'basic tests) (null tests))
          ;; Create buf1 in org-mode, fill with a few tasks
          (org-toodledo-test-message "TEST: Creating 3 tasks in buf1")
          (org-toodledo-test-setup-buffer buf1)
          (org-toodledo-test-create-tasks 3)
          (org-toodledo-initialize "TASKS")
          (sit-for 2)

          ;; Create buf2 in org-mode, initialize, pull in tasks
          (org-toodledo-test-message "TEST: Syncing 3 tasks into buf2")
          (org-toodledo-test-setup-buffer buf2)
          (org-toodledo-initialize "TASKS")
          (org-toodledo-test-verify-tasks buf2 "Task 1" "Task 2" "Task 3")
          (sit-for 2)

          ;; Modify Task 1 and sync
          (org-toodledo-test-message "TEST: Modifying Task 1 in buf2")
          (org-toodledo-test-goto-task "Task 1")
          (end-of-line)
          (insert-string " - modified")
          (org-toodledo-test-equal (org-toodledo-sync) '(1 0 0 0 1 0 0)
                                   "Synced out 1 modified task")
          (sit-for 2)

          ;; Back to buf1, sync -- verify
          (org-toodledo-test-message "TEST: Syncing modified Task 1")
          (set-buffer buf1)
          (org-toodledo-test-equal (org-toodledo-sync) '(1 1 0 0 0 0 0)
                                   "Synced in 1 modified task")
          (org-toodledo-test-verify-tasks buf1
                                          "Task 1 - modified"
                                          "Task 2" "Task 3")
          (sit-for 2)

          ;; Modify Task 3 and sync
          (org-toodledo-test-message "TEST: Modifying Task 3")
          (org-toodledo-test-goto-task "Task 3")
          (end-of-line)
          (insert-string " - modified")
          (org-toodledo-test-equal (org-toodledo-sync) '(1 0 0 0 1 0 0)
                                   "Synced out 1 modified task")
          (sit-for 2)

          ;; Back to buf2, sync -- verify
          (org-toodledo-test-message "TEST: Syncing modified Task 3")
          (set-buffer buf2)
          (org-toodledo-test-equal (org-toodledo-sync) '(1 1 0 0 0 0 0)
                                   "Synced in 1 modified task")
          (org-toodledo-test-verify-tasks buf2
                                          "Task 1 - modified"
                                          "Task 2" "Task 3 - modified")
          (sit-for 2)

          ;; Compare all tasks between both buffers
          (org-toodledo-test-message
           "TEST: Comparing all tasks between buffers")
          (org-toodledo-test-compare-tasks buf1 buf2
                                           "Task 1 - modified"
                                           "Task 2" "Task 3 - modified")

          (org-toodledo-test-message "TEST: Cleanup")
          (org-toodledo-test-cleanup)
          (sit-for 2)
          )

        ;;
        ;; Encoding special chars
        ;;
        (when (or (member 'special tests) (null tests))
          (org-toodledo-test-message "TEST: Encoding special characters")
          (org-toodledo-test-setup-buffer buf2)
          (org-toodledo-test-message "Initializing buf2: %S"
                                     (org-toodledo-initialize "TASKS"))
          (sit-for 2)

          (org-toodledo-test-setup-buffer buf1)
          (org-toodledo-test-message "Initializing buf1: %S"
                                     (org-toodledo-initialize "TASKS"))
          (sit-for 2)

          (goto-char (point-max))
          (insert-string "** TODO ORGTOODLEDOTEST:Task é字\nBody é字")
          (org-toodledo-test-equal (org-toodledo-sync) '(1 0 0 1 0 0 0)
                                   "Synced out 1 new task with special chars")
          (sit-for 2)

          (set-buffer buf2)
          (org-toodledo-test-equal (org-toodledo-sync) '(1 1 0 0 0 0 0)
                                   "Synced in 1 task with special chars")
          (org-toodledo-test-compare-tasks buf1 buf2 "Task é字")
          (sit-for 2)

          (org-toodledo-test-message "TEST: Cleanup")
          (org-toodledo-test-cleanup)
          (sit-for 2)
          )

        ;;
        ;; Bulk test -- make sure more than 50 works
        ;;
        (when (or (member 'bulk tests) (null tests))
          (org-toodledo-test-setup-buffer buf2)
          (org-toodledo-initialize "TASKS")
          (sit-for 2)

          (org-toodledo-test-setup-buffer buf1)
          (org-toodledo-initialize "TASKS")
          (sit-for 2)

          (org-toodledo-test-message "TEST: Create 60 tasks")
          (set-buffer buf1)
          (org-toodledo-test-create-tasks 60 2 100)
          (org-toodledo-test-equal (org-toodledo-sync) '(60 0 0 60 0 0 0)
                                   "Synced 60 new tasks")
          (sit-for 2)

          (set-buffer buf2)
          (org-toodledo-test-equal (org-toodledo-sync) '(60 60 0 0 0 0 0)
                                   "Synced in 60 tasks")
          (sit-for 2)

          (org-toodledo-test-message "TEST: Cleanup")
          (org-toodledo-test-cleanup)
          (sit-for 2)
          )

        ;;
        ;; Folder tests
        ;;
        (when (or (member 'folder tests) (null tests))
          ;;
          (setq org-toodledo-sim-db-folders nil)
          (org-toodledo-sim-db-new-folder "1" "Folder1" "1")
          (org-toodledo-sim-db-new-folder "2" "Folder2" "2")
          (org-toodledo-sim-db-new-folder "3" "Deleted Tasks" "3")

          ;; Support-mode - folder is just property
          (let ((org-toodledo-folder-support-mode nil))

            (org-toodledo-test-setup-buffer buf2)
            (org-toodledo-initialize "TASKS")
            (sit-for 2)

            (org-toodledo-test-setup-buffer buf1)
            (org-toodledo-initialize "TASKS")
            (sit-for 2)

            (org-toodledo-test-message "TEST: Create 1 task")
            (set-buffer buf1)
            (org-toodledo-test-create-tasks 1 2 200)
            (org-toodledo-test-equal (org-toodledo-sync) '(1 0 0 1 0 0 0)
                                     "Synced out 1 new task from buf1")
            (sit-for 2)

            (set-buffer buf2)
            (org-toodledo-test-equal (org-toodledo-sync) '(1 1 0 0 0 0 0)
                                     "Synced in 1 task into buff2")
            (sit-for 2)

            (org-toodledo-test-goto-task "Task 200")
            (org-entry-put (point) "ToodledoFolder" "TESTFOLDER")
            (org-toodledo-test-equal
             (org-toodledo-sync) '(1 0 0 0 1 0 0)
             "Synced out 1 modified task from buf2 with folder")
            (sit-for 2)

            (set-buffer buf1)
            (org-toodledo-test-equal
             (org-toodledo-sync) '(1 1 0 0 0 0 0)
             "Synced in 1 modified task into buf1 with folder")
            (sit-for 2)

            (org-toodledo-test-compare-tasks buf1 buf2 "Task 200")

            (org-toodledo-test-message "TEST: Cleanup")
            (org-toodledo-test-cleanup)
            (sit-for 2)
            )
          )

        ;;
        ;; Tag tests
        ;;
        (when (or (member 'tag tests) (null tests))
          (org-toodledo-test-setup-buffer buf2)
          (org-toodledo-initialize "TASKS")
          (sit-for 2)

          (org-toodledo-test-setup-buffer buf1)
          (org-toodledo-initialize "TASKS")
          (sit-for 2)

          (org-toodledo-test-message "TEST: Create 10 tasks")
          (set-buffer buf1)
          (org-toodledo-test-create-tasks 10 2 300)
          (org-toodledo-test-equal
           (org-toodledo-sync) '(10 0 0 10 0 0 0)
           "Synced out 10 new tasks from buf1")
          (sit-for 2)

          (set-buffer buf2)
          (org-toodledo-test-equal
           (org-toodledo-sync) '(10 10 0 0 0 0 0)
           "Synced in 10 task into buf2")
          (sit-for 2)

          (mapcar (lambda (id)
                    (org-toodledo-test-goto-task (concat "Task " id))
                    (org-set-tags-to (list (concat "Foo" id))))
                  '("303" "305" "307"))
          (org-toodledo-test-equal
           (org-toodledo-sync) '(3 0 0 0 3 0 0)
           "Synced out 3 modified task from buf2 with tags")
          (sit-for 2)

          (set-buffer buf1)
          (org-toodledo-test-equal
           (org-toodledo-sync) '(3 3 0 0 0 0 0)
           "Synced in 3 modified task into buf1 with tags")
          (sit-for 2)

          (org-toodledo-test-compare-tasks
           buf1 buf2
           "Task 300" "Task 301" "Task 302" "Task 303" "Task 304"
           "Task 305" "Task 306" "Task 307" "Task 308" "Task 309")

          (set-buffer buf1)
          (mapcar (lambda (id)
                    (org-toodledo-test-goto-task (concat "Task " id))
                    (org-set-tags-to (list (concat "Foo" id) "@Bar")))
                  '("303" "305" "307"))

          (mapcar (lambda (id)
                    (org-toodledo-test-goto-task (concat "Task " id))
                    (org-set-tags-to (list "@Bar")))
                  '("300" "304" "309"))
          (org-toodledo-test-equal
           (org-toodledo-sync) '(6 0 0 0 6 0 0)
           "Synced out 6 modified task from buf1 with tags")
          (sit-for 2)

          (set-buffer buf2)
          (org-toodledo-test-equal
           (org-toodledo-sync) '(6 6 0 0 0 0 0)
           "Synced in 6 modified task into buf2 with tags")
          (sit-for 2)

          (org-toodledo-test-compare-tasks
           buf1 buf2
           "Task 300" "Task 301" "Task 302" "Task 303" "Task 304"
           "Task 305" "Task 306" "Task 307" "Task 308" "Task 309")

          (org-toodledo-test-message "TEST: Cleanup")
          (org-toodledo-test-cleanup)
          (sit-for 2)
          )

        ;;
        ;; Simulated server tests
        ;;
        (when (or (member 'sim tests) (null tests))
          (org-toodledo-sim-init 0)

          ;; Start with 2 tasks on the server
          (org-toodledo-test-message "TEST: creating 2 tasks in db to start")

          (org-toodledo-sim-db-new-task
           (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 1")))

          (org-toodledo-sim-db-new-task
           (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 2")))

          ;; Sync them into buf1
          (org-toodledo-test-message "TEST: initializing buf1")
          (org-toodledo-test-setup-buffer buf1)
          (org-toodledo-test-equal
           (org-toodledo-initialize "TASKS") '(2 2 0 0 0 0 0)
           "Synced in initial tasks 1,2 into buf1")

          ;; Add 2 more tasks
          (org-toodledo-test-message "TEST: adding tasks 3,4 to buf1")
          (org-toodledo-test-create-tasks 2 2 3)
          (org-toodledo-test-equal
           (org-toodledo-sync) '(2 0 0 2 0 0 0)
           "Synced out new tasks 3,4 from buf1")

          (org-toodledo-test-message "TEST: Syncing all 4 tasks into buf2")
          (org-toodledo-test-setup-buffer buf2)
          (org-toodledo-test-equal
           (org-toodledo-initialize "TASKS") '(4 4 0 0 0 0 0)
           "Synced in initial tasks 1-4 into buf2")

          (org-toodledo-test-compare-tasks buf1 buf2
                                           "Task 1" "Task 2" "Task 3" "Task 4")


          ;; Add tasks 5,6 to buf2
          (org-toodledo-test-message "TEST: Creating 2 more tasks in buf2")
          (org-toodledo-test-create-tasks 2 2 5)
          (org-toodledo-test-message "...simulating invalid-key")
          ;; inject and invalid-key, this should be handled silently
          (setq org-toodledo-sim-invalid-key t)
          (org-toodledo-test-equal (org-toodledo-sync) '(2 0 0 2 0 0 0)
                                   "Synced out new tasks 5,6 from buf2")

          ;; Pull those new tasks 5,6 into buf1
          (org-toodledo-test-message
           "TEST: Pulling 2 latest tasks back into buf1")
          (set-buffer buf1)
          (org-toodledo-test-equal (org-toodledo-sync) '(2 2 0 0 0 0 0)
                                   "Synced in new tasks 5,6 into buf1")

          ;; Delete tasks 2,4,6 in buf1
          (org-toodledo-test-message "TEST: Deleting 3 tasks in buf1")
          (mapc
           (lambda (id)
             (org-toodledo-test-goto-task (format "Task %d" id))
             (org-toodledo-mark-task-deleted))
           '(2 4 6))

          (org-toodledo-test-equal (org-toodledo-sync) '(3 0 0 0 0 3 0)
                                   "Synced out deleted tasks 2,4,6 from buf1")

          ;; Sync in the deleted tasks into buf2
          (org-toodledo-test-message "TEST: Syncing 3 deleted tasks in buf2")
          (set-buffer buf2)
          (org-toodledo-test-equal (org-toodledo-sync) '(3 0 3 0 0 0 0)
                                   "Synced in deleted tasks 2,4,6 into buf2")

          ;; Delete task 1 on the server *and* in buf1, and attempt a sync
          ;; which will cause an "Invalid ID error"
          (org-toodledo-test-message
           "TEST: Deleting 1 task from buf1 and svr to generate delete error")
          (set-buffer buf1)
          (org-toodledo-test-goto-task "Task 1")
          (let* ((task (org-toodledo-parse-current-task))
                 (id (org-toodledo-task-id task)))
            (org-toodledo-sim-db-delete-task id t))
          (org-toodledo-mark-task-deleted)
          (org-toodledo-test-equal
           (org-toodledo-sync) '(1 0 0 0 0 1 1)
           "Attempted to sync out deleted task 1 from buf1 with error")

          ;; Simulate a task error with a bad context-id
          (org-toodledo-test-message
           "TEST: Creating task 7 with a simulated context-id error")
          (org-toodledo-test-create-tasks 1 2 7)
          (org-toodledo-test-goto-task "Task 7")
          (end-of-line)
          (insert-string " simerror=9")
          (org-toodledo-test-equal
           (org-toodledo-sync) '(1 0 0 1 0 0 1)
           "Attempted to sync out task 7 from buf1 with error")

          ;; Fix the task
          (org-toodledo-test-message "TEST: Fixing task 7")
          (org-toodledo-test-goto-task "Task 7")
          (re-search-forward " simerror=9")
          (replace-match "")
          (org-toodledo-test-equal
           (org-toodledo-sync) '(1 0 0 1 0 0 0)
           "Attempted to sync out task 7 from buf1 with no error")


          ;; Sync into buf2
          (org-toodledo-test-message "TEST: Syncing task 7 into buf2")
          (set-buffer buf2)
          (org-toodledo-test-equal
           (org-toodledo-sync) '(1 1 0 0 0 0 0)
           "Sync in task 7 into buf2")
          (org-toodledo-test-compare-tasks buf1 buf2
                                           "Task 3" "Task 5" "Task 7")

          ;; Make task 7 an error again
          (org-toodledo-test-message
           "TEST: Editing 7 with a simulated context-id error")
          (org-toodledo-test-goto-task "Task 7")
          (end-of-line)
          (insert-string " simerror=9")
          (org-toodledo-test-equal
           (org-toodledo-sync) '(1 0 0 0 1 0 1)
           "Attempted to sync out task 7 from buf2 with error")
          )

        ;;
        ;; Sim folder tests
        ;;
        (when (or (member 'sim-folder tests)
                  (member 'sim tests)
                  (null tests))
          (org-toodledo-sim-init 1)

          ;;
          (setq org-toodledo-sim-db-folders nil)
          (org-toodledo-sim-db-new-folder "1" "Folder1" "1")
          (org-toodledo-sim-db-new-folder "2" "Folder2" "2")
          (org-toodledo-sim-db-new-folder "3" "Deleted Tasks" "3")

          ;; Support-mode - folder is just property
          (let ((org-toodledo-folder-support-mode nil))

            (org-toodledo-test-setup-buffer buf2)
            (org-toodledo-initialize "TASKS")

            (org-toodledo-test-setup-buffer buf1)
            (org-toodledo-initialize "TASKS")

            (org-toodledo-test-message "TEST: Create 1 task")
            (set-buffer buf1)
            (org-toodledo-test-create-tasks 1 2 200)
            (org-toodledo-test-equal
             (org-toodledo-sync) '(1 0 0 1 0 0 0)
             "Synced out 1 new task from buf1")

            (set-buffer buf2)
            (org-toodledo-test-equal
             (org-toodledo-sync) '(1 1 0 0 0 0 0)
             "Synced in 1 task into buff2")

            (org-toodledo-test-goto-task "Task 200")
            (org-entry-put (point) "ToodledoFolder" "TESTFOLDER")
            (org-toodledo-test-equal
             (org-toodledo-sync) '(1 0 0 0 1 0 0)
             "Synced out 1 modified task from buf2 with folder")

            (set-buffer buf1)
            (org-toodledo-test-equal
             (org-toodledo-sync) '(1 1 0 0 0 0 0)
             "Synced in 1 modified task into buf1 with folder")

            (org-toodledo-test-compare-tasks buf1 buf2 "Task 200")
            )
          )

        ;;
        ;; Simulated tests with parent tasks
        ;;
        (when (or (member 'sim-hier tests)
                  (member 'sim tests)
                  (null tests))
          (org-toodledo-sim-init 1)

          ;; Start with 2 tasks on the server
          (org-toodledo-test-message "TEST: creating 2 tasks in db to start")

          (org-toodledo-sim-db-new-task
           (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 1")
                                       '("id" . "10010")))

          (org-toodledo-sim-db-new-task
           (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 2")
                                       '("id" . "10011")
                                       '("parent" . "10010")))

          ;; Sync them into buf1
          (org-toodledo-test-message "TEST: initializing buf1")
          (org-toodledo-test-setup-buffer buf1)
          (org-toodledo-test-equal
           (org-toodledo-initialize "TASKS") '(2 2 0 0 0 0 0)
           "Synced in initial tasks 1,2 into buf1")
          )

        ;;
        ;; Simulated completed task archiving
        ;;
        (when (or (member 'sim-completed tests)
                  (member 'sim tests)
                  (null tests))
          (let ((org-toodledo-archive-completed-tasks t)
                (org-archive-location "%s_archive::"))

            ;; First round, completed tasks in non-pro-mode
            (org-toodledo-sim-init 0)

            ;; Start with 2 tasks on the server
            (org-toodledo-test-message "TEST: creating 2 tasks in db to start")

            (org-toodledo-sim-db-new-task
             (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 1")
                                         '("id" . "10010")))

            (org-toodledo-sim-db-new-task
             (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 2")
                                         '("id" . "10011")))

            ;; Sync them into buf1
            (org-toodledo-test-message "TEST: initializing buf1")
            (org-toodledo-test-setup-buffer buf1)
            (org-toodledo-test-equal
             (org-toodledo-initialize "TASKS") '(2 2 0 0 0 0 0)
             "Synced in initial tasks 1,2 into buf1")

            ;; Mark task 1 done, sync, make sure it disappears into
            ;; the archive file
            (org-toodledo-test-goto-task "Task 1")
            (org-todo "DONE")
            (org-toodledo-test-equal
             (org-toodledo-sync) '(1 0 0 0 1 0 0)
             "Synced out 1 completed task")
            (org-toodledo-test-verify-tasks buf1 "Task 2")
            (org-toodledo-test-equal
             t (file-exists-p (format "%s_archive" buf1-file))
             "Buf 1 archive file created")

            ;; Sync into buffer 2, should only see Task 2
            (org-toodledo-test-message "TEST: syncing into buffer 2")
            (org-toodledo-test-setup-buffer buf2)
            (org-toodledo-test-equal
             (org-toodledo-initialize "TASKS") '(1 1 0 0 0 0 0)
             "Synced in remaining 1 task into buf2")
            (org-toodledo-test-verify-tasks buf1 "Task 2")

            ;; Second round, completed tasks in pro-mode
            (org-toodledo-sim-init 1)

            ;; Start with 2 tasks on the server
            (org-toodledo-test-message
             "TEST: creating 2 parent tasks with 2 child tasks in db to start")

            (org-toodledo-sim-db-new-task
             (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 1")
                                         '("id" . "10010")))

            (org-toodledo-sim-db-new-task
             (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 2")
                                         '("id" . "10011")
                                         '("parent" . "10010")))

            (org-toodledo-sim-db-new-task
             (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 3")
                                         '("id" . "10012")))

            (org-toodledo-sim-db-new-task
             (org-toodledo-sim-make-task '("title". "ORGTOODLEDOTEST:Task 4")
                                         '("id" . "10013")
                                         '("parent" . "10012")))

            ;; Sync them into buf1
            (org-toodledo-test-message "TEST: initializing buf1")
            (org-toodledo-test-setup-buffer buf1)
            (org-toodledo-test-equal
             (org-toodledo-initialize "TASKS") '(4 4 0 0 0 0 0)
             "Synced in initial tasks 1-4 into buf1")

            ;; Mark task 1 done, sync, make sure it and it's child
            ;; task disappear into the archive file
            (org-toodledo-test-goto-task "Task 1")
            (org-todo "DONE")
            ;(error "Forced fail")
            (org-toodledo-test-equal
             (org-toodledo-sync) '(2 0 0 0 2 0 0)
             "Synced out 2 completed task")
            (org-toodledo-test-verify-tasks buf1 "Task 3" "Task 4")
            (org-toodledo-test-equal
             t (file-exists-p (format "%s_archive" buf1-file))
             "Buf 1 archive file created")

            ;; Sync into buffer 2, should only see Task 2
            (org-toodledo-test-message "TEST: syncing into buffer 2")
            (org-toodledo-test-setup-buffer buf2)
            (org-toodledo-test-equal
             (org-toodledo-initialize "TASKS") '(2 2 0 0 0 0 0)
             "Synced in remaining 2 task into buf2")
            (org-toodledo-test-verify-tasks buf1 "Task 3" "Task 4")
            )
          )

        ;; All done
        (setq org-toodledo-test-mode nil)
        (setq org-toodledo-sim-mode nil)

        (org-toodledo-test-cleanup-file buf1-file)
        (org-toodledo-test-cleanup-file (format "%s_archive" buf1-file))
        (org-toodledo-test-cleanup-file buf2-file)
        (org-toodledo-test-cleanup-file (format "%s_archive" buf2-file))
        (exec-cmd "rm -rf /tmp/org-toodledo-test*")

        (org-toodledo-test-message
         "Tests complete: %d/%d tests passed"
         (- org-toodledo-test-count org-toodledo-test-fail)
         org-toodledo-test-count)
        )
      )
    )
  )

(defun org-toodledo-test-cleanup-file (file)
  (let ((buf (find-buffer-visiting file)))
    (when buf
      (set-buffer buf)
      (save-buffer)
      (kill-buffer))))

(defun org-toodledo-test-message (str &rest args)
  (save-excursion
    (set-buffer org-toodledo-test-msg-buf)
    (end-of-buffer)
    (let ((msg (concat (apply 'format (append (list str) args)) "\n")))
      (insert (concat "[" (format-time-string "%H:%M:%S") "] " msg))
      (org-toodledo-debug msg))))

(defun org-toodledo-test-debug-buffer (buf)
  (save-excursion
    (set-buffer buf)
    (copy-region-as-kill (point-min) (point-max))
    (set-buffer (get-buffer-create "*Org-toodledo-debug*"))
    (end-of-buffer)
    (insert (concat "["
                    (format-time-string "%H:%M:%S")
                    (format "] ========== Buffer %S ==========" buf) "\n"))
    (yank)
    (insert (concat "\n["
                    (format-time-string "%H:%M:%S")
                    (format "] ========== End of buffer %S ==========" buf)
                    "\n"))
    )
  )

(defun org-toodledo-test-check (value str &rest args)
  (setq org-toodledo-test-count (1+ org-toodledo-test-count))
  (cond
   ((not (null value))
    (setq org-toodledo-test-pass (1+ org-toodledo-test-pass))
    (org-toodledo-test-message "PASSED: %s"
                               (apply 'format (append (list str) args)))
    t)

   (t
    (setq org-toodledo-test-fail (1+ org-toodledo-test-fail))
    (org-toodledo-test-message "FAILED: %s"
                               (apply 'format (append (list str) args)))
    (org-toodledo-test-debug-buffer buf1)
    (org-toodledo-test-debug-buffer buf2)
    (when org-toodledo-test-stop-on-error (error "FAILED"))
    nil
   )))

(defun org-toodledo-test-equal (value1 value2 str &rest args)
  (setq org-toodledo-test-count (1+ org-toodledo-test-count))
  (cond
   ((equal value1 value2)
    (setq org-toodledo-test-pass (1+ org-toodledo-test-pass))
    (org-toodledo-test-message "PASSED: %s"
                               (apply 'format (append (list str) args))))

   (t
    (setq org-toodledo-test-fail (1+ org-toodledo-test-fail))
    (org-toodledo-test-message "FAILED: %s [%S != %S]"
             (apply 'format (append (list str) args))
             value1 value2
             )
    (org-toodledo-test-debug-buffer buf1)
    (org-toodledo-test-debug-buffer buf2)
    (when org-toodledo-test-stop-on-error (error "FAILED"))
    )))

(defun org-toodledo-test-goto-task (title &optional buffer)
  (if buffer
      (set-buffer buffer)
    (setq buffer (current-buffer)))
  (goto-char (point-min))
  (org-toodledo-test-check
   (re-search-forward (concat "ORGTOODLEDOTEST:" title "\\b") nil t)
   "Find task '%s' in buffer '%S'" title (current-buffer))
  )

(defun org-toodledo-test-setup-buffer (name)
  (let ((buf (get-buffer-create name)))
    (set-buffer buf)
    (erase-buffer)
    (when (not (eq major-mode 'org-mode))
      (org-mode))
    (insert-string "* TASKS\n")
    (save-buffer)
    )
  )

(defun org-toodledo-test-create-tasks (num &optional level start)
  (end-of-buffer)
  (let (result)
    (do ((i 0 (1+ i))) ((>= i num) nil)
      (insert-string (format "%s TODO ORGTOODLEDOTEST:Task %d\n"
                             (make-string (or level 2) ?*) (+ i (or start 1))))
      (setq result (append result (list (format "Task %d" i)))))
    result))


(defun org-toodledo-test-cleanup()
  "Delete all test tasks"
  (interactive)
  (condition-case nil
      (progn
        (setq org-toodledo-test-mode t)
        (let ((buf (get-buffer-create "*Org-toodledo-cleanup*"))
              (buf-file (make-temp-file "/tmp/org-toodledo-test-cleanup")))
          (set-buffer buf)
          (erase-buffer)
          (write-file buf-file)
          (when (not (eq major-mode 'org-mode))
            (org-mode))
          (insert-string "* TASKS\n")
          (org-toodledo-initialize "TASKS")

          ;; Delete all tasks
          (goto-char (point-min))
          (while (re-search-forward "ORGTOODLEDOTEST" nil t)
            (org-toodledo-mark-task-deleted)
            )

          (org-toodledo-sync)
          (save-buffer)
          (kill-buffer)
          )
        )
    )
  )

(defun org-toodledo-test-compare-tasks (buf1 buf2 &rest titles)
  (mapcar
   (lambda (title)
     (let (task1 task2)
       ;; Get the task from buf1
       (set-buffer buf1)
       (when (org-toodledo-test-goto-task title)
         (setq task1 (org-toodledo-parse-current-task))

         ;; Get the task from buf2
         (set-buffer buf2)
         (when (org-toodledo-test-goto-task title)
           (setq task2 (org-toodledo-parse-current-task))

           ;; Compare all fields
           (mapc
            (lambda (task1-assoc)
              (let* ((key1 (car task1-assoc))
                     (value1 (or (cdr task1-assoc) "0"))
                     (task2-assoc (assoc key1 task2))
                     (value2 (or (cdr task2-assoc) "0")))
                (when (member key1 '("id" "title" "status" "completed"
                                     "repeat" "repeatfrom" "context" "duedate"
                                     "startdate" "folder" "goal" "priority"
                                     "note" "length" "parent" "hash" "tag"))
                  (org-toodledo-test-message
                   "Comparing key %s='%s'" key1 value1)

                  (org-toodledo-test-check task2-assoc
                                           "Found key '%s' in task2" key1)

                  (org-toodledo-test-equal value1 value2
                                           "Key '%s' values match" key1))))
            task1)))))
   titles
   )
  )

(defun org-toodledo-test-verify-tasks (buffer &rest titles)
  (set-buffer buffer)
  (goto-char (point-min))
  (let ((count 0))
    (while (re-search-forward "ORGTOODLEDOTEST" nil t)
      (setq count (1+ count)))
    (org-toodledo-test-equal
     count (length titles)
     "Verify buffer %S has %d tasks" buffer (length titles))
    )

  (mapcar
   (lambda (title)
     (org-toodledo-test-check
      (save-excursion
        (goto-char (point-min))
        (re-search-forward (concat "ORGTOODLEDOTEST:" title "\\b") nil t))
      "Find task in buffer %S: %s" buffer title))
   titles))

(defun org-toodledo-cleanup-buffers ()
  (interactive)
  (save-excursion
    (loop
     for buf in (buffer-list)
     do (let ((fname (buffer-file-name buf)))
          (when (and fname (string-match ".*/tmp/org-toodledo-test.*" fname))
            (set-buffer buf)
            (save-buffer)
            (kill-buffer))))))

(provide 'org-toodledo-test)
