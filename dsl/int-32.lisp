(in-package :salem-layer-util)

(defun int-32-decode (buf off io dhold)
  "Transforms an int-32 decode into proper CL code"
  (let ((arg (car (cdr (dhold-argv dhold)))))
    (if (consp arg)
        ;;multiple args
        (if (dhold-lflag dhold)
            (error "Invalid use of LET keyword")
            ;;add new data
            (setf (car (dhold-data dhold))
                  (append (car (dhold-data dhold))
                          `((setf ,off 
                                  (rw-sints ,buf ,off 4 ,io ";~A (int-32):"
                                            ;;correctly generate lists for
                                            ;;multi arg function
                                            (list 
                                             ,@(loop 
                                                  for a in arg
                                                  collect `(list ,a)))))))))
        ;;singular
        (if (dhold-lflag dhold)
            ;;add new data
            (setf (car (dhold-data dhold))
                  (append (car (dhold-data dhold))
                          `((rw-sint ,buf ,off 4 ,io
                                     ,(cat-args 
                                       (car (cdr (dhold-argv dhold))) 
                                       " (int-32):"))
                            (setf ,off 
                                  ,(car (cdr (cdr (dhold-lflag dhold))))))))
            ;;add enw data
            (setf (car (dhold-data dhold))
                  (append (car (dhold-data dhold))
                          `((setf ,off 
                                  (rw-sint ,buf ,off 4 ,io
                                           ,(cat-args 
                                             (car (cdr (dhold-argv dhold))) 
                                             " (int-32):"))))))))
    ;;move argv and reset lflag
    (setf (dhold-argv dhold) (cdr (dhold-argv dhold)))
    (setf (dhold-lflag dhold) ())))

(defun int-32-encode (buffer io dhold)
  "Transforms an int-32 encode into proper CL code"
  (if (dhold-lflag dhold)
      (progn
        (setf (car (dhold-data dhold))
              (append (car (dhold-data dhold))
                      `( ((,(dhold-lflag dhold) (readin-int ,io)))
                         (inte ,(dhold-lflag dhold) 4 ,buffer) ))) 
        (setf (dhold-lflag dhold) nil))
      (setf (car (dhold-data dhold))
            (append (car (dhold-data dhold))
                    `((rinte ,io 4 ,buffer))))))

