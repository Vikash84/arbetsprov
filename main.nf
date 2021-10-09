#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include {fastqc; fastp; quast; multiqc} from "./modules/qc.nf"
include {spades; spades_hybrid} from "./modules/assembly.nf"
include {build_db; assign_taxonomy;
         download_related} from "./modules/taxonomy.nf"
include {prodigal; rename_proteins; abricate} from "./modules/annotation.nf"
include {cd_hit; select_clusters; mafft;
         concat_msa; fasttree} from "./modules/phylogeny.nf"

workflow {
    Channel
        .fromPath(params.ion)
        .map { file -> tuple(file.simpleName, file) }
        .dump()
        .set{ ion }
    
    Channel
        .fromPath(params.nanopore)
        .map { file -> tuple(file.simpleName, file) }
        .dump()
        .set{ nanopore }

    fastp(ion, params.fastp_trim, params.fastp_filter, params.fastp_len)

    // processes cannot be reused in DSL2
    // We therefore merge both raw and trimmed reads channels
    // to only use the fastqc process once
    Channel
        .fromPath(params.ion)
        .map { file -> tuple(file.simpleName, file) }
        .concat(fastp.out.trimmed_reads)
        .set{fastqc_input}
    fastqc(fastqc_input)

    fastqc.out.all
        .collect()
        .set{fastqc_for_multiqc}

    spades(fastp.out.trimmed_reads)
    spades_hybrid(fastp.out.trimmed_reads, nanopore)
    quast(spades.out.contigs, spades_hybrid.out.contigs)
    
    multiqc(fastqc_for_multiqc, quast.out.report)

    build_db()
    assign_taxonomy(spades.out.contigs, build_db.out.database)
    download_related(assign_taxonomy.out.lca)
    prodigal(spades.out.contigs)
    rename_proteins(prodigal.out.proteins)

    rename_proteins.out.proteins
        .join(download_related.out.proteomes, by:0)
        .dump()
        .set{cd_hit_input}
    cd_hit(cd_hit_input)
    select_clusters(cd_hit.out.clusters, cd_hit_input)

    select_clusters.out.clusters
        .flatten()
        .dump()
        .set{mafft_input}
    mafft(mafft_input)
    concat_msa(mafft.out.msa.collect())
    fasttree(concat_msa.out.msa)

    abricate(spades_hybrid.out.contigs)
}