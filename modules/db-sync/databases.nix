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
    "--multi-thread-streams=0"
    "--retries=10"
    "--retries-sleep=30s"
    "--low-level-retries=20"
    "--timeout=5m"
    "--contimeout=60s"
    "--ftp-idle-timeout=60s"
  ];

  blastSyncSubdir = ".staging";
  blastPostSync = ''
    # Verify MD5 checksums before extraction; delete corrupt files so
    # rclone re-downloads them on the next sync run.
    failed=0
    for f in .staging/*.tar.gz; do
      [ -f "$f" ] || continue
      md5="$f.md5"
      if [ -f "$md5" ]; then
        if ! (cd .staging && md5sum -c "$(basename "$md5")"); then
          echo "MD5 FAILED: $f — removing both files for re-download"
          rm -f "$f" "$md5"
          failed=1
          continue
        fi
      else
        echo "WARNING: no checksum file for $f — skipping verification"
      fi
      echo "Extracting $f ..."
      tar xzf "$f"
    done
    if [ "$failed" -ne 0 ]; then
      echo "Some files failed MD5 verification and were removed."
      echo "They will be re-downloaded on the next sync."
      exit 1
    fi
  '';
in
{
  services.db-sync.databases = {
    # NCBI BLAST databases
    # https://ftp.ncbi.nlm.nih.gov/blast/db/
    blast-nr = {
      enable = lib.mkDefault false;
      syncUrl = "ncbi:blast/db/";
      syncSubdir = blastSyncSubdir;
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
      syncSubdir = blastSyncSubdir;
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
      syncSubdir = blastSyncSubdir;
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
      syncSubdir = blastSyncSubdir;
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
