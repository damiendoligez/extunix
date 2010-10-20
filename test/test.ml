
open OUnit
open ExtUnix.All

let with_unix_error f () =
  try f ()
  with Unix.Unix_error(e,f,a) -> assert_failure (Printf.sprintf "Unix_error : %s(%s) : %s" f a (Unix.error_message e))

let test_eventfd () =
  let e = eventfd 2 in
  assert_equal 2L (eventfd_read e);
  eventfd_write e 3L;
  assert_equal 3L (eventfd_read e)

let test_uname () =
  let t = uname () in
  let _s: string = Uname.to_string t in
  ()

let test_fadvise () =
  fadvise (Unix.descr_of_in_channel stdin) 0 0 POSIX_FADV_NORMAL;
  LargeFile.fadvise (Unix.descr_of_out_channel stdout) 0L 0L POSIX_FADV_SEQUENTIAL;
  ()

let test_fallocate () =
  let (name,ch) = Filename.open_temp_file "extunix" "test" in
  try
    let fd = Unix.descr_of_out_channel ch in
    fallocate fd 0 1;
    LargeFile.fallocate fd 1L 1L;
    assert_equal (Unix.fstat fd).Unix.st_size 2;
    close_out_noerr ch;
    Unix.unlink name
  with exn -> close_out_noerr ch; Unix.unlink name; raise exn

(* Copied from oUnit.ml *)
(* Utility function to manipulate test *)
let rec test_decorate g tst =
  match tst with
    | TestCase f -> 
        TestCase (g f)
    | TestList tst_lst ->
        TestList (List.map (test_decorate g) tst_lst)
    | TestLabel (str, tst) ->
        TestLabel (str, test_decorate g tst)

let test_unistd =
  [
  "ttyname" >:: begin fun () ->
    ignore (ttyname Unix.stdin);
    ignore (ttyname Unix.stdout);
  end;
  "pgid" >:: begin fun () ->
    let pgid = getpgid 0 in
    setpgid 0 0;
    assert_equal (getpgid 0) (Unix.getpid ());
    setpgid 0 pgid;
    assert_equal (getpgid 0) pgid;
  end;
  ]

let test_realpath () =
  let printer x = x in
  assert_equal ~printer (Unix.getcwd ()) (realpath ".");
  assert_equal ~printer (Unix.getcwd ()) (realpath "./././/./");
  assert_equal ~printer "/" (realpath "///");
  assert_equal ~printer "/" (realpath "/../../");
  ()

let test_signalfd () =
  let pid = Unix.getpid () in
  let (_:int list) = Unix.sigprocmask Unix.SIG_BLOCK [Sys.sigusr1; Sys.sigusr2] in
  let fd = signalfd ~sigs:[Sys.sigusr1] ~flags:[] () in 
  Unix.kill pid Sys.sigusr1;
  let fd = signalfd ~fd ~sigs:[Sys.sigusr1; Sys.sigusr2] ~flags:[] () in
  Unix.set_nonblock fd;
  Unix.kill pid Sys.sigusr2;
  let printer = string_of_int in
  assert_equal ~printer Sys.sigusr1 (ssi_signo_sys (signalfd_read fd));
  assert_equal ~printer Sys.sigusr2 (ssi_signo_sys (signalfd_read fd));
  Unix.close fd

let () =
  let tests = ("tests" >::: [
    "eventfd" >:: test_eventfd;
    "uname" >:: test_uname;
    "fadvise" >:: test_fadvise;
    "fallocate" >:: test_fallocate;
    "unistd" >::: test_unistd;
    "realpath" >:: test_realpath;
    "signalfd" >:: test_signalfd;
  ]) in
  ignore (run_test_tt_main (test_decorate with_unix_error tests))

