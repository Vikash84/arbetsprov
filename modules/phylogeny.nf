process cd_hit {
    tag "clustering: ${prefix}"
    label "cd_hit"
    input:
        tuple val(prefix), path(proteins), path(related_proteomes)
    output:
        tuple val(prefix), path("${prefix}.clustered.faa.clstr"), emit: clusters
    script:
        """
        # first concatenate inputs
        cat *.faa > cdhit_proteins.faa
        # then run cd-hit
        cd-hit -i cdhit_proteins.faa -o "${prefix}.clustered.faa" \
            -d 0 -d 0.95 -n 5 -T 6
        """
}


process select_clusters {
    tag "clustering: ${prefix}"
    label "biopython"
    input:
        tuple val(prefix), path(clusters)
        tuple val(prefix), path(proteins), path(related_proteomes)
    output:
        tuple val(prefix), path("clusters/*.faa"), emit: clusters
    script:
        """
        mkdir clusters
        select_clusters.py --clstr "${clusters}" --faa_dir . --outdir clusters
        """
}