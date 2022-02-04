{ pkgs ? import <nixpkgs> {} }: with pkgs; mkShell { buildInputs = [
    pkg-config
    gtk3
    gtk3-x11
];}
