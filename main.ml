
open Printf

let (|>) f g = g f (* default in OCaml 4.01 *)
let (@@) f x = f x

let rec exude p = function
  | [] -> raise Not_found
  | x :: l -> (match p x with
      | Some y -> y
      | None -> exude p l)

type latlon = (float * float)

type trkpt = latlon (* we don't need (yet) another crap *)
type trkseg = latlon list
type trk = trkseg list
type gpx = trk list

let gpx_of_channel channel : gpx =
  let i = Xmlm.make_input (`Channel channel) in
  let module Xml = Xmlm_shit in
  let r =
    Xml.find_tag "gpx" i @@
      fun _ i -> Xml.input_list_ignore_other i @@
        Xml.expect_tag "trk" @@
          fun _ i -> Xml.input_list_ignore_other i @@
            Xml.expect_tag "trkseg" @@
              fun _ i -> Xml.input_list_ignore_other i @@
                Xml.expect_tag "trkpt" @@
                  fun ((_, _), attrs) i ->
                    let lat =
                      exude
                        (fun ((_, name), value) ->
                          if name = "lat" then Some value else None)
                        attrs
                    and lon =
                      exude
                        (fun ((_, name), value) ->
                          if name = "lon" then Some value else None)
                        attrs in
                    Xml.close_tag i;
                    Xml.Parsed (float_of_string lat, float_of_string lon)
  in
  match r with
  | Xml.Parsed r -> r
  | Xml.Failed -> assert false (* bad gpx *)

let print_gpx =
  List.iter
    (List.iter
      (List.iter
        (fun (lat, lon) -> printf "(%f, %f)\n" lat lon)))

let print_as_wkt gpx =
  print_string "MULTILINESTRING (";
  List.map
    (List.map
      (fun l ->
        String.concat ", " @@
        List.map
          (fun (lat, lon) -> sprintf "%f %f" lon lat)
          l)) gpx
  |> List.flatten
  |> List.map (fun s -> sprintf "(%s)" s)
  |> String.concat ", "
  |> print_string;
  print_string ")\n"

let () =
  let gpx = gpx_of_channel stdin in
  (* check if it empty or one-point track *)
  let counter = ref 0 in
  List.iter
    (List.iter
      (List.iter
        (fun _ -> incr counter))) gpx;
  if !counter <= 2
  then
    (eprintf "You need at least 2 points track!\n";
    exit 1)
  else
    print_as_wkt gpx

