(in-package :salem-layer-util)

(defparameter *skip-old* t)
(defparameter *print-skip* nil)

;;;file utils
(defun solve-files-1 (folder)
  "Finds all RES and CACHE files within specified folder"
  (let ((files (directory folder))
        (lst ()))
    (dolist (f files)
      (when *verbose* 
        (format t "  ~A~%" f))
      (let ((type (pathname-type f))
            (name (car (last (pathname-directory f)))))
        (cond
          ((or (string= type "res")    ;.res files
               (string= type "cached") ;.cache files
               ;;.res/.cache folder files [decoded]
               (not (null (or (search ".res" name)
                              (search ".cache" name)))))
           (push f lst))
          ((null (pathname-name f))    ; directory
           (setf lst 
                 (append (solve-files-1 (make-pathname :directory 
                                                       (pathname-directory f)
                                                       :name :wild
                                                       :type :wild))
                         lst))))))
    lst))

(defun solve-files (folder splits)
  "Finds all RES and CACHE files within specified folder"
  (when *verbose*
    (format t "~A~%" "Finding RES and CACHE files..."))
  (let* ((files (solve-files-1 (make-pathname :directory `(:relative ,folder)
                                              :name :wild
                                              :type :wild)))
         (split-size (round (/ (length files) splits)))
         (file-lists ()))
    (dotimes (i (1- splits))
      (push (subseq files (* i split-size) (+ (* i split-size) split-size)) 
            file-lists))
    (push (subseq files (* (1- splits) split-size)) file-lists)
    file-lists))
    
    

(defun get-date-1 (file)
  "Returns the last time for which the file was last edited"
  (if (probe-file file)
      (file-write-date file)
      0))

(defun get-date (file)
  "Returns the last time for which the file was last edited"
  (let ((date (get-date-1 file)))
    (when (and (/= date 0)
               (null (pathname-name file)))
      (let ((files (directory (make-pathname :directory 
                                             (pathname-directory file)
                                             :name :wild
                                             :type :wild))))
        (dolist (f files)
          (max date (get-date f)))))
    date))

;;; modes
;;D
(defun decode-file (files out-fold)
  (dolist (file files)
    (let ((out-file file))
      ;;check if user gave absolute pathnames
      (when (/= 0 (search (directory-namestring file) 
                         (directory-namestring *default-pathname-defaults*)))
        (setf out-file (subseq (directory-namestring file)
                               (length (directory-namestring
                                        *default-pathname-defaults*)))))
      ;;resolve
      (setf out-file (concatenate 'string
                                  out-fold
                                  out-file
                                  "/"))
      (when *verbose* 
        (format t "IN:~A~%OUT:~A~%" file out-file))
      ;;Considering the user chose this file to be decoded, skipping 
      ;;checking for timestamps
      (load-resource-by-res file out-file))))

;;DA
(defun decode-files (files out-fold in-fold)
  "Decodes the list of FILES into OUTF"
  (let ((len (length files))
        (i 0))
    (format t "Processing: ~A files~%" len)
    ;;loop throuhg entire list
    (dolist (file files)
      ;;progress report for non-verbose
      (incf i)
      (when (not *verbose*)
        (format t "File: ~A/~A~%" i len))
      ;;resolve output location
      (let ((outf  (subseq (directory-namestring file)
                           (length (directory-namestring 
                                    *default-pathname-defaults*))))
            (out-file ""))
        (if (search in-fold outf :test #'equalp)
            (setf out-file (concatenate 'string
                                        out-fold
                                        "/"
                                        (subseq outf (length in-fold))
                                        "/"
                                        (pathname-name file)
                                        ".res/"))
            (setf out-file (concatenate 'string
                                        out-fold
                                        "/"
                                        outf
                                        "/"
                                        (pathname-name file)
                                        ".res/")))
        ;;check timestamps
        (if (or (not *skip-old*)
              (> (get-date file) (get-date out-file)))
            (load-resource-by-res file out-file)
            (when *print-skip*
              (format t "Skipping: ~A, too old.~%" file)))))))
;;E
(defun encode-file (files out-fold)
  (values files out-fold)
  ;;loop through entire list
  (dolist (file files)
    ;;resolve output location
    (let ((out-file file))
      ;;remove absolute
      (unless (null (search (directory-namestring file) 
                            (directory-namestring 
                             *default-pathname-defaults*)))
        (setf out-file (subseq (directory-namestring file)
                               (length (directory-namestring
                                        *default-pathname-defaults*)))))
      ;;resolve
      (setf out-file (concatenate 'string
                                  out-fold
                                  (subseq out-file 0 (1- (length out-file)))))
      (when *verbose* 
        (format t "IN:~A~%OUT:~A~%" file out-file))
      (load-resource-by-folder file out-file))))


;;EA
(defun encode-files (files in-fold out-fold)
  "Encodes the list of FILES into OUTF"
  (let ((len (length files))
        (i 0))
    (format t "Processing: ~A files~%" len)
    ;;loop through entire list
    (dolist (file files)
      ;;progress report for non-verbose
      (incf i)
      (when (not *verbose*)
        (format t "File: ~A/~A~%" i len))
       
      ;;resolve output location
      (let ((outf (subseq (directory-namestring file)
                          (length (directory-namestring 
                                   *default-pathname-defaults*))))
            (out-file ""))
        (if (search in-fold outf)
            (setf out-file 
                  (concatenate 'string
                               out-fold
                               "/"
                               (subseq outf
                                       (length in-fold))))
            (setf out-file
                  (concatenate 'string
                               out-fold
                               "/"
                               outf)))
        (setf out-file (subseq out-file 0 (1- (length out-file))))
        ;;check timestamps
        (if (or (not *skip-old*)
                (> (get-date file) (get-date out-file)))
            (load-resource-by-folder file out-file)
            (when *print-skip*
              (format t "Skipping: ~A, too old.~%" file)))))))
      
            

(defun load-layers (layer-dir)
  (let ((config (concatenate 'string layer-dir "/common.lisp"))
        (layers (directory (make-pathname :directory `(:relative ,layer-dir)
                                          :name :wild :type "lisp"))))
    ;;load config
    (when (probe-file config)
      (load config))
    ;;load layers
    (loop 
       for layer in layers
       do (when (string/= config 
                          (subseq (namestring layer) 
                                  (length (namestring
                                           *default-pathname-defaults*))))
            (load layer)))))
            
;;; salem-layer-util

(defun run (&key (mode :d) (skip-old t) (verbose t) (print-skip nil) (threads 1) (args ()) (layers "layers/salem"))
  "salem-layer-util version - 1.0.0
Usage: (salem-layer-util:run KEYS)
Possible KEYS include:
 (:mode              Determines the mode of the program 
                      [DEFAULT-VALUE: :d]
   Possible modes include:
    :d              Decodes file(s) given through ARGS by list of pathnames
                     default output folder: dout
    :e              Encodes file(s) given through ARGS by list of pathnames
                     default output folder: dres
    :da             Decodes a set of files within a specified directory into another
    :ea             Encodes a set of files within a specified directory into another)
   Note: for :da and :ea the two directories needed should be provided through &key args
         first arg within the args list should be source-folder
         second arg within the args list should be result-folder
 (:skip-old t/nil)   Skip processing older files
                      [DEFAULT-VALUE: t]
 (:verbose t/nil)    Be verbose 
                      [DEFAULT-VALUE: t]
 (:print-skip t/nil) Print skipped files 
                      [DEFAULT-VALUE: nil]
 (:threads n)        Number of threads to execute decoding/encoding of files 
                      [DEFAULT-VALUE: 1]
                      As of right now threads key doesn't change anything.
 (:args '(...))      A list of arguments for the mode given"
  (in-package :salem-layer-util)
  (when (zerop (length args))
    (princ (documentation 'run 'function))
    (return-from run nil))
  (setf threads 1) ;Unlock proper threading is fixed, defaults to 1
  (setf *skip-old* skip-old)
  (setf *verbose* verbose)
  (setf *print-skip* print-skip)
  ;;reset layer table and load layers
  (reset-layers) 
  (load-layers layers)
  (case mode
    (:d  (decode-file args "dout/"))
    (:e  (encode-file args "dres/"))
    (:da (decode-files (car (solve-files (car args) threads)) 
                       (car (cdr args))
                       (car args)))
    (:ea (encode-files (car (solve-files (car args) threads))
                       (car args)
                       (car (cdr args))))))

(defun split-by-space (str)
  (let ((lst ())
        (start 0))
    (do* ((i 0 (1+ i)))
         ((= (length str) i))
      (when (char= #\  (char str i))
        (setf lst (append lst (list (subseq str start i))))
        (setf start (1+ i))))
    (setf lst (append lst (list (subseq str start))))
    lst))


#+sbcl 
(defun bootstrap ()
  "salem-layer-util version - 1.0.0
Usage: (salem-layer-util:run KEYS)
Possible KEYS include:
 :mode              Determines the mode of the program 
                      [DEFAULT-VALUE: :d]
   Possible modes include:
    d              Decodes file(s) given through ARGS by list of pathnames
                     default output folder: dout
    e              Encodes file(s) given through ARGS by list of pathnames
                     default output folder: dres
    da             Decodes a set of files within a specified directory into another
    ea             Encodes a set of files within a specified directory into another)
   Note: for :da and :ea the two directories needed should be provided through &key args
         first arg within the args list should be source-folder
         second arg within the args list should be result-folder
 :skip-old t/nil    Skip processing older files
                      [DEFAULT-VALUE: t]
 :verbose t/nil     Be verbose 
                      [DEFAULT-VALUE: t]
 :print-skip t/nil  Print skipped files 
                      [DEFAULT-VALUE: nil]
 :threads n         Number of threads to execute decoding/encoding of files 
                      [DEFAULT-VALUE: 1]
                      As of right now threads key doesn't change anything.
 :args \"...\"      A list of arguments for the mode given
 :layers FILE_PATH  File path to the layers needed to be loaded
                      [DEFAULT-VALUE: layers/salem]
                    Within this folder should be your layer definitions and a file named
                    `config.lisp\' with the information needed for the layers"
  (let ((mode :d)
        (skip-old t)
        (verbose t)
        (print-skip nil)
        (threads 1)
        (args ())
        (layers "layers/salem"))
    (if (= 1 (length sb-ext:*posix-argv*))
        (princ (documentation 'bootstrap 'function))
        (do* ((argv (cdr sb-ext:*posix-argv*) (cdr argv))
              (arg (car argv) (car argv)))
             ((null argv) (progn
                            (run :mode mode :skip-old skip-old 
                                 :verbose verbose :print-skip print-skip
                                 :threads threads :args args :layers layers)))
          (cond
            ((string= arg ":mode")
             (setf argv (cdr argv))
             (setf mode (intern (string-upcase (car argv)) :keyword)))
            ((string= arg ":skip-old")
             (setf argv (cdr argv))
             (setf skip-old (read-from-string (car argv))))
            ((string= arg ":verbose")
             (setf argv (cdr argv))
             (setf verbose (read-from-string (car argv))))
            ((string= arg ":print-skip")
             (setf argv (cdr argv))
             (setf print-skip (read-from-string (car argv))))
            ((string= arg ":threads")
             (setf argv (cdr argv))
             (setf threads (read-from-string (car argv))))
            ((string= arg ":args")
             (setf argv (cdr argv))
             (setf args (split-by-space (car argv))))
            ((string= arg ":layers")
             (setf argv (cdr argv))
             (setf layers (car argv)))))))
  (sb-ext:exit :code 0))
