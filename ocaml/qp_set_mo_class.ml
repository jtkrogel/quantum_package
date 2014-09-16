open Qputils;;
open Qptypes;;
open Core.Std;;

(*
 * Command-line arguments
 * ----------------------
 *)

let build_mask from upto n_int =
  let from  = MO_number.to_int from
  and upto  = MO_number.to_int upto
  and n_int = N_int_number.to_int n_int
  in
  let rec build_mask bit = function
    | 0 -> []
    | i -> 
        if ( i = upto ) then
          Bit.One::(build_mask Bit.One (i-1))
        else if ( i = from ) then
          Bit.One::(build_mask Bit.Zero (i-1))
        else
          bit::(build_mask bit (i-1))
  in
  let starting_bit = 
    if ( (upto >= n_int*64) || (upto < 0) ) then Bit.One
    else Bit.Zero
  in
  build_mask starting_bit (n_int*64)
  |> List.rev
;;

let apply_mask mask n_int mo_tot_num = 
  let full_mask  = build_mask (MO_number.of_int 1) (MO_number.of_int mo_tot_num) n_int in
  let occ_mask   = build_mask (MO_number.of_int 1) (MO_number.of_int mo_tot_num) n_int in
  let virt_mask  = Bitlist.not_operator occ_mask
  in
  let newmask = Bitlist.and_operator occ_mask mask
  in
  newmask |> Bitlist.to_string |> print_string;
  Ezfio.set_bitmasks_n_int (N_int_number.to_int n_int);
  Ezfio.set_bitmasks_bit_kind 8;
  Ezfio.set_bitmasks_n_mask_gen 1;
  let d =  newmask
    |> Bitlist.to_int64_list
  in 
  let rec append_d = function
    | 1 -> List.rev d
    | n -> d@(append_d (n-1))
  in
  let d = append_d 12 in
  Ezfio.ezfio_array_of_list ~rank:4 ~dim:([| (N_int_number.to_int n_int) ; 2; 6; 1|]) ~data:d 
  |> Ezfio.set_bitmasks_generators ; 
;;



let failure s = raise (Failure s)
;;

type t = 
  | Core
  | Inactive
  | Active
  | Virtual
  | Deleted
  | None
;;

let t_to_string = function
  | Core -> "core"
  | Inactive -> "inactive"
  | Active -> "active"
  | Virtual -> "virtual"
  | Deleted -> "deleted"
  | None -> assert false
;;

let run ?(core="[]") ?(inact="[]") ?(act="[]") ?(virt="[]") ?(del="[]") ezfio_filename =

  Ezfio.set_file ezfio_filename ;
  if not (Ezfio.has_mo_basis_mo_tot_num ()) then
    failure "mo_basis/mo_tot_num not found" ;

  let mo_tot_num = Ezfio.get_mo_basis_mo_tot_num () in
  let n_int = N_int_number.of_int (Ezfio.get_determinants_n_int ()) in


  let mo_class = Array.init mo_tot_num ~f:(fun i -> None) in

  let apply_class l = 
    let rec apply_class t = function
    | [] -> ()
    | k::tail -> let i = MO_number.to_int k in
        begin
          match mo_class.(i-1) with
          | None -> mo_class.(i-1) <- t ;
            apply_class t tail;
          | x -> failure 
             (Printf.sprintf "Orbital %d is defined both in the %s and %s spaces"
             i (t_to_string x) (t_to_string t))
        end
    in
    match l with
    | MO_class.Core     x -> apply_class Core      x
    | MO_class.Inactive x -> apply_class Inactive  x
    | MO_class.Active   x -> apply_class Active    x
    | MO_class.Virtual  x -> apply_class Virtual   x
    | MO_class.Deleted  x -> apply_class Deleted   x
  in

  MO_class.create_core     core  |> apply_class ;
  MO_class.create_inactive inact |> apply_class ;
  MO_class.create_active   act   |> apply_class ;
  MO_class.create_virtual  virt  |> apply_class ;
  MO_class.create_deleted  del   |> apply_class ;

  for i=1 to (Array.length mo_class)
  do
    if (mo_class.(i-1) = None) then
      failure (Printf.sprintf "Orbital %d is not specified (mo_tot_num = %d)" i mo_tot_num)
  done;
  
  
  MO_class.create_core     core  |> MO_class.to_string |> print_endline ;
  MO_class.create_inactive inact |> MO_class.to_string |> print_endline ;
  MO_class.create_active   act   |> MO_class.to_string |> print_endline ;
  MO_class.create_virtual  virt  |> MO_class.to_string |> print_endline ;
  MO_class.create_deleted  del   |> MO_class.to_string |> print_endline ;
  (*


  let inactive_mask = Range.of_string inact
    |> List.map ~f:MO_number.of_int
    |> Bitlist.of_mo_number_list n_int
  and active_mask = 
    let s = Range.of_string act
    in
      List.map ~f:MO_number.of_int s
      |> Bitlist.of_mo_number_list n_int
  in
  let mask = 
    Bitlist.not_operator inactive_mask
    |> Bitlist.and_operator active_mask
  in apply_mask mask n_int mo_tot_num
*)
;;

let ezfio_file =
  let failure filename = 
        eprintf "'%s' is not an EZFIO file.\n%!" filename;
        exit 1
  in
  Command.Spec.Arg_type.create
  (fun filename ->
    match Sys.is_directory filename with
    | `Yes -> 
        begin
          match Sys.is_file (filename / ".version") with
          | `Yes -> filename
          | _ -> failure filename
        end
    | _ -> failure filename
  )
;;

let default range =
  let failure filename = 
        eprintf "'%s' is not a regular file.\n%!" filename;
        exit 1
  in
  Command.Spec.Arg_type.create
  (fun filename ->
    match Sys.is_directory filename with
    | `Yes -> 
        begin
          match Sys.is_file (filename / ".version") with
          | `Yes -> filename
          | _ -> failure filename
        end
    | _ -> failure filename
  )
;;

let spec =
  let open Command.Spec in
  empty 
  +> flag "core"   (optional string) ~doc:"range Range of core orbitals"
  +> flag "inact"  (optional string) ~doc:"range Range of inactive orbitals"
  +> flag "act"    (optional string) ~doc:"range Range of active orbitals"
  +> flag "virt"   (optional string) ~doc:"range Range of virtual orbitals"
  +> flag "del"    (optional string) ~doc:"range Range of deleted orbitals"
  +> anon ("ezfio_filename" %: ezfio_file)
;;

let command = 
    Command.basic 
    ~summary: "Set the orbital classes in an EZFIO directory"
    ~readme:(fun () ->
      "The range of MOs has the form : \"[36-53,72-107,126-131]\"
        ")
    spec
    (fun core inact act virt del ezfio_filename () -> run ?core ?inact ?act ?virt ?del ezfio_filename )
;;

let () =
    Command.run command


