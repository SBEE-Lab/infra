# Pre-configured bioinformatics databases
{ pkgs, lib, ... }:
{
  services.icebox.databases = {
    # NCBI BLAST databases
    # https://ftp.ncbi.nlm.nih.gov/blast/db/
    blast-nr = {
      enable = lib.mkDefault false;
      syncMethod = "script";
      syncScript = ''
        ${pkgs.blast}/bin/update_blastdb.pl --decompress --passive nr
      '';
      schedule = lib.mkDefault "weekly";
    };

    blast-nt = {
      enable = lib.mkDefault false;
      syncMethod = "script";
      syncScript = ''
        ${pkgs.blast}/bin/update_blastdb.pl --decompress --passive nt
      '';
      schedule = lib.mkDefault "weekly";
    };

    blast-refseq-protein = {
      enable = lib.mkDefault false;
      syncMethod = "script";
      syncScript = ''
        ${pkgs.blast}/bin/update_blastdb.pl --decompress --passive refseq_protein
      '';
      schedule = lib.mkDefault "weekly";
    };

    blast-swissprot = {
      enable = lib.mkDefault false;
      syncMethod = "script";
      syncScript = ''
        ${pkgs.blast}/bin/update_blastdb.pl --decompress --passive swissprot
      '';
      schedule = lib.mkDefault "weekly";
    };

    # UniProt Reference Clusters
    # https://ftp.uniprot.org/pub/databases/uniprot/uniref/
    uniref90 = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/";
      syncMethod = "rsync";
      syncArgs = [
        "--delete"
        "--include=uniref90.fasta.gz"
        "--include=uniref90.xml.gz"
        "--exclude=*"
      ];
      schedule = lib.mkDefault "monthly";
    };

    uniref100 = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref100/";
      syncMethod = "rsync";
      syncArgs = [
        "--delete"
        "--include=uniref100.fasta.gz"
        "--include=uniref100.xml.gz"
        "--exclude=*"
      ];
      schedule = lib.mkDefault "monthly";
    };

    # Protein Data Bank (PDB)
    # https://www.wwpdb.org/ftp/pdb-ftp-sites
    pdb = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://rsync.rcsb.org/ftp_data/structures/divided/pdb/";
      syncMethod = "rsync";
      syncArgs = [ "--delete" ];
      schedule = lib.mkDefault "weekly";
    };

    # PDB in mmCIF format
    pdb-mmcif = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://rsync.rcsb.org/ftp_data/structures/divided/mmCIF/";
      syncMethod = "rsync";
      syncArgs = [ "--delete" ];
      schedule = lib.mkDefault "weekly";
    };

    # RNAcentral
    # https://rnacentral.org/downloads
    rnacentral = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://ftp.ebi.ac.uk/pub/databases/RNAcentral/current_release/";
      syncMethod = "rsync";
      syncArgs = [ "--delete" ];
      schedule = lib.mkDefault "monthly";
    };

    # AlphaFold Database (requires rclone with GCS)
    # https://alphafold.ebi.ac.uk/download
    alphafold = {
      enable = lib.mkDefault false;
      syncUrl = "gs://public-datasets-deepmind-alphafold-v4";
      syncMethod = "rclone";
      syncArgs = [
        "--transfers=8"
        "--checkers=8"
      ];
      schedule = lib.mkDefault "quarterly"; # Very large, sync less frequently
    };

    # Pfam
    # https://www.ebi.ac.uk/interpro/download/pfam/
    pfam = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/";
      syncMethod = "rsync";
      syncArgs = [ "--delete" ];
      schedule = lib.mkDefault "monthly";
    };

    # Rfam (RNA families)
    # https://rfam.org/
    rfam = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://ftp.ebi.ac.uk/pub/databases/Rfam/CURRENT/";
      syncMethod = "rsync";
      syncArgs = [ "--delete" ];
      schedule = lib.mkDefault "monthly";
    };

    # InterPro
    # https://www.ebi.ac.uk/interpro/download/
    interpro = {
      enable = lib.mkDefault false;
      syncUrl = "rsync://ftp.ebi.ac.uk/pub/databases/interpro/current_release/";
      syncMethod = "rsync";
      syncArgs = [ "--delete" ];
      schedule = lib.mkDefault "monthly";
    };
  };
}
