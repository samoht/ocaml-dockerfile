(*
 * Copyright (c) 2015 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

(** OPAM-specific Dockerfile rules *)

open Dockerfile
open Printf

(** RPM rules *)
module RPM = struct

  let install_base_packages =
    Linux.RPM.dev_packages ()

  let add_opensuse_repo = function
  | `CentOS7 ->
      let url = "http://download.opensuse.org/repositories/home:ocaml/CentOS_7/home:ocaml.repo" in
      run "curl -o /etc/yum.repos.d/home:ocaml.repo -OL %s" url @@
      run "yum -y upgrade"
  | `CentOS6 ->
      let url = "http://download.opensuse.org/repositories/home:ocaml/CentOS_6/home:ocaml.repo" in
      run "curl -o /etc/yum.repos.d/home:ocaml.repo -OL %s" url @@
      run "yum -y upgrade"

  let install_system_ocaml =
    Linux.RPM.install "ocaml ocaml-camlp4-devel ocaml-ocamldoc"

  let install_system_opam = function
  | `CentOS7 -> Linux.RPM.install "opam aspcud"
  | `CentOS6 -> Linux.RPM.install "opam"
end

(** Debian rules *)
module Apt = struct

  let install_base_packages =
    Linux.Apt.update @@
    Linux.Apt.install "sudo pkg-config git build-essential m4 software-properties-common unzip curl libx11-dev"

  let install_system_ocaml =
    Linux.Apt.install "ocaml ocaml-native-compilers camlp4-extra"

  let install_system_opam =
    Linux.Apt.install "opam aspcud"

  let add_opensuse_repo distro=
    let url = "http://download.opensuse.org/repositories/home:/ocaml/" in
    match distro with
    | `Ubuntu v ->
        let version = match v with `V14_04 -> "14.04" | `V14_10 -> "14.10" in
        let repo = sprintf "deb %s/xUbuntu_%s/ /" url version in
        run "echo %S > /etc/apt/sources.list.d/opam.list" repo @@
        run "curl -OL %s/xUbuntu_%s/Release.key" url version @@
        run "apt-key add - < Release.key" @@
        Linux.Apt.update @@
        run "apt-get -y dist-upgrade"
    | `Debian v ->
        let version = match v with `Stable -> "7.0" | `Testing -> "8.0" in
        let repo = sprintf "deb %s/Debian_%s/ /" url version in
        run "echo %S > /etc/apt/sources.list.d/opam.list" repo @@
        run "curl -OL %s/Debian_%s/Release.key" url version @@
        run "apt-key add - < Release.key" @@
        Linux.Apt.update @@
        run "apt-get -y dist-upgrade"
end

let run_as_opam fmt = Linux.run_as_user "opam" fmt
let opamhome = "/home/opam"

let opam_init
  ?(repo="git://github.com/ocaml/opam-repository")
  ?compiler_version () =
    env ["OPAMYES","1"] @@
    run_as_opam "git clone %s" repo @@
    run_as_opam "opam init -a -y %s/opam-repository" opamhome @@
    maybe (run_as_opam "opam switch -y %s") compiler_version @@
    workdir "%s/opam-repository" opamhome @@
    run_as_opam "opam config exec -- ocaml -version" @@
    run_as_opam "opam --version" @@
    onbuild (run_as_opam "cd %s/opam-repository && git pull && opam update -u -y" opamhome)

let install_opam_from_source ?prefix ?(branch="1.2") () =
  run "git clone -b %s git://github.com/ocaml/opam" branch @@
  Linux.run_sh "cd opam && make cold && make %s install"
    (match prefix with None -> "" |Some p -> "prefix=\""^p^"\"")

let install_ext_plugin =
  Linux.run_sh "%s %s %s"
           "git clone git://github.com/avsm/opam-installext &&"
           "cd opam-installext && make &&"
           "make PREFIX=/usr install && cd .. && rm -rf opam-installext"

let header img tag =
  comment "Autogenerated by OCaml-Dockerfile scripts" @@
  from ~tag img @@
  maintainer "Anil Madhavapeddy <anil@recoil.org>"

let generate_dockerfiles output_dir =
  List.iter (fun (name, docker) ->
    printf "Generating: %s/%s/Dockerfile\n" output_dir name;
    (match Sys.command (sprintf "mkdir -p %s/%s" output_dir name) with
    | 0 -> () | _ -> raise (Failure (sprintf "mkdir -p %s/%s" output_dir name)));
    let fout = open_out (output_dir^"/"^name^"/Dockerfile") in
    output_string fout (string_of_t docker))

