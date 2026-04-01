# Pre-configured bioinformatics databases
#
# All databases use rclone for sync. Remote names are defined in
# modules/db-sync/default.nix (rcloneConf).
#
# Remotes:
#   ncbi:  FTP  ftp.ncbi.nlm.nih.gov (anonymous)
#   ebi:   HTTP ftp.ebi.ac.uk
#   pdbj:  HTTP ftp.pdbj.org (Japan mirror, closest to KREN)
{ lib, ... }:
let
  # NCBI FTP limits concurrent connections; restrict rclone accordingly
  ncbiFtpArgs = [
    "--transfers=1"
    "--checkers=1"
  ];

  blastPostSync = ''
    for f in *.tar.gz; do
      [ -f "$f" ] || continue
      echo "Extracting $f ..."
      tar xzf "$f" && rm "$f" "$f.md5"
    done
  '';
in
{
  services.db-sync.databases = {
    # NCBI BLAST databases
    # https://ftp.ncbi.nlm.nih.gov/blast/db/
    blast-nr = {
      enable = lib.mkDefault false;
      syncUrl = "ncbi:blast/db/";
      syncArgs = ncbiFtpArgs ++ [
        "--filter"
        "+ nr.*.tar.gz"
        "--filter"
        "+ nr.*.tar.gz.md5"
        "--filter"
        "- *"
      ];
      postSync = blastPostSync;
      schedule = lib.mkDefault "weekly";
    };

    blast-nt = {
      enable = lib.mkDefault false;
      syncUrl = "ncbi:blast/db/";
      syncArgs = ncbiFtpArgs ++ [
        "--filter"
        "+ nt.*.tar.gz"
        "--filter"
        "+ nt.*.tar.gz.md5"
        "--filter"
        "- *"
      ];
      postSync = blastPostSync;
      schedule = lib.mkDefault "weekly";
    };

    blast-refseq-protein = {
      enable = lib.mkDefault false;
      syncUrl = "ncbi:blast/db/";
      syncArgs = ncbiFtpArgs ++ [
        "--filter"
        "+ refseq_protein.*.tar.gz"
        "--filter"
        "+ refseq_protein.*.tar.gz.md5"
        "--filter"
        "- *"
      ];
      postSync = blastPostSync;
      schedule = lib.mkDefault "weekly";
    };

    blast-swissprot = {
      enable = lib.mkDefault false;
      syncUrl = "ncbi:blast/db/";
      syncArgs = ncbiFtpArgs ++ [
        "--filter"
        "+ swissprot.tar.gz"
        "--filter"
        "+ swissprot.tar.gz.md5"
        "--filter"
        "+ swissprot-prot-metadata.json"
        "--filter"
        "- *"
      ];
      postSync = blastPostSync;
      schedule = lib.mkDefault "weekly";
    };

    # UniProt Reference Clusters (EBI mirror)
    # https://ftp.uniprot.org/pub/databases/uniprot/uniref/
    uniref90 = {
      enable = lib.mkDefault false;
      syncUrl = "ebi:pub/databases/uniprot/uniref/uniref90/";
      syncArgs = [
        "--filter"
        "+ uniref90.fasta.gz"
        "--filter"
        "+ uniref90.xml.gz"
        "--filter"
        "- *"
      ];
      schedule = lib.mkDefault "monthly";
    };

    uniref100 = {
      enable = lib.mkDefault false;
      syncUrl = "ebi:pub/databases/uniprot/uniref/uniref100/";
      syncArgs = [
        "--filter"
        "+ uniref100.fasta.gz"
        "--filter"
        "+ uniref100.xml.gz"
        "--filter"
        "- *"
      ];
      schedule = lib.mkDefault "monthly";
    };

    # Protein Data Bank — PDBj Japan mirror (closest to KREN)
    # https://pdbj.org/info/archive
    pdb = {
      enable = lib.mkDefault false;
      syncUrl = "pdbj:pub/pdb/data/structures/divided/pdb/";
      schedule = lib.mkDefault "weekly";
    };

    # PDB in mmCIF format
    pdb-mmcif = {
      enable = lib.mkDefault false;
      syncUrl = "pdbj:pub/pdb/data/structures/divided/mmCIF/";
      schedule = lib.mkDefault "weekly";
    };

    # RNAcentral
    # https://rnacentral.org/downloads
    rnacentral = {
      enable = lib.mkDefault false;
      syncUrl = "ebi:pub/databases/RNAcentral/current_release/";
      schedule = lib.mkDefault "monthly";
    };

    # AlphaFold Database (GCS public bucket)
    # https://alphafold.ebi.ac.uk/download
    alphafold = {
      enable = lib.mkDefault false;
      syncUrl = "gs://public-datasets-deepmind-alphafold-v4";
      syncArgs = [
        "--transfers=8"
        "--checkers=8"
      ];
      schedule = lib.mkDefault "quarterly";
    };

    # Pfam
    # https://www.ebi.ac.uk/interpro/download/pfam/
    pfam = {
      enable = lib.mkDefault false;
      syncUrl = "ebi:pub/databases/Pfam/current_release/";
      schedule = lib.mkDefault "monthly";
    };

    # Rfam (RNA families)
    # https://rfam.org/
    rfam = {
      enable = lib.mkDefault false;
      syncUrl = "ebi:pub/databases/Rfam/CURRENT/";
      schedule = lib.mkDefault "monthly";
    };

    # InterPro
    # https://www.ebi.ac.uk/interpro/download/
    interpro = {
      enable = lib.mkDefault false;
      syncUrl = "ebi:pub/databases/interpro/current_release/";
      schedule = lib.mkDefault "monthly";
    };
  };
}
