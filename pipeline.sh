#!/bin/bash

if [[ $# != 3 ]]; then
	exit 1
fi

input_name=${1}
output_name=${2}
refgenome_name=${3}

dir_path='/mnt/causes-vnx2/glenn'
input_path=${dir_path}'/fq'

if [[ $refgenome_name == 'v38' ]]; then
	refgenome=${dir_path}'/refgenome/v38/15_GRCh38'
	refgenome_fasta=${dir_path}'/refgenome/v38/15_GRCh38.fasta'
	output_path=${dir_path}'/v38'
elif [[ $refgenome_name == 'T2T' ]]; then
	refgenome=${dir_path}'/refgenome/T2T/chm13'
	refgenome_fasta=${dir_path}'/refgenome/T2T/chm13.draft_v1.1.fasta'
	output_path=${dir_path}'/T2T'
else
	exit 1
fi

t2t_hg38_chain=${dir_path}'/refgenome/T2T/t2t-chm13-v1.1.grch38.over.chain'
v38_hg19_chain=${dir_path}'/refgenome/v38/hg38ToHg19.over.chain.gz'

hg19_ref_genome=${dir_path}'/refgenome/hg19/hg19.fasta'
v38_ref_genome=${dir_path}'/refgenome/v38/15_GRCh38.fasta'

R1_file=$(ls -m ${dir_path}/fq/${input_name}*R1* 2> /dev/null | tr -d " \t\n\r")
R2_file=$(ls -m ${dir_path}/fq/${input_name}*R2* 2> /dev/null | tr -d " \t\n\r")

#MapBowtie2
/opt/tools/bowtie2-2.2.6/bowtie2  -x ${refgenome} -1 ${R1_file} -2 ${R2_file} -S ${output_path}/${output_name}_bowtie2.sam  -p 8 --very-sensitive -X 1000 --met-stderr --rg-id ${output_name} --rg "SM:${output_name}                PL:illumina" 2> ${output_path}/${output_name}_bowtie2.stderr

#BamSortIndex
/opt/tools/samtools-1.2/samtools view  -bS ${output_path}/${output_name}_bowtie2.sam | /opt/tools/samtools-1.2/samtools sort  -m1000000000 - ${output_path}/${output_name}_bowtie2.sorted
/opt/tools/samtools-1.2/samtools index ${output_path}/${output_name}_bowtie2.sorted.bam

#MarkDuplicates
/opt/tools/jdk1.7.0_79/bin/java -jar /opt/tools/picard-tools-1.139/picard.jar MarkDuplicates I=${output_path}/${output_name}_bowtie2.sorted.bam O=${output_path}/${output_name}_bowtie2_dupremoved.sorted.bam REMOVE_DUPLICATES=false M=${output_path}/${output_name}_bowtie2_DuplicateResults.txt
/opt/tools/samtools-1.2/samtools index ${output_path}/${output_name}_bowtie2_dupremoved.sorted.bam

#Realign
/opt/tools/jdk1.7.0_79/bin/java -jar /opt/tools/GATK/GenomeAnalysisTK.jar -T RealignerTargetCreator -R ${refgenome_fasta} -minReads 5 -I ${output_path}/${output_name}_bowtie2_dupremoved.sorted.bam -o ${output_path}/${output_name}_bowtie2_indelsites.intervals -nt 16
/opt/tools/jdk1.7.0_79/bin/java -jar /opt/tools/GATK/GenomeAnalysisTK.jar -T IndelRealigner -model USE_READS -R ${refgenome_fasta} -targetIntervals ${output_path}/${output_name}_bowtie2_indelsites.intervals -I ${output_path}/${output_name}_bowtie2_dupremoved.sorted.bam -o ${output_path}/${output_name}_bowtie2_dupremoved_realigned.sorted.bam
/opt/tools/samtools-1.2/samtools index ${output_path}/${output_name}_bowtie2_dupremoved_realigned.sorted.bam

#mpileupv0.1.19
/opt/tools/samtools-0.1.19/samtools mpileup -Bgf ${refgenome_fasta} ${output_path}/${output_name}_bowtie2_dupremoved_realigned.sorted.bam | /opt/tools/samtools-0.1.19/bcftools/bcftools view -gvc - > ${output_path}/${output_name}_bowtie2_dupremoved_realigned_v0.1.19mpileup.bcf
/opt/tools/samtools-0.1.19/bcftools/vcfutils.pl varFilter -Q20 -a 5 ${output_path}/${output_name}_bowtie2_dupremoved_realigned_v0.1.19mpileup.bcf | awk '(match ($1,"##") || $6 > 30)' > ${output_path}/${output_name}_bowtie2_dupremoved_realigned_v0.1.19mpileup.vcf
/opt/tools/tabix/bgzip ${output_path}/${output_name}_bowtie2_dupremoved_realigned_v0.1.19mpileup.vcf
/opt/tools/tabix/tabix ${output_path}/${output_name}_bowtie2_dupremoved_realigned_v0.1.19mpileup.vcf.gz

#Liftover
if [[ $refgenome_name == 'T2T' ]]; then
	/opt/tools/jdk1.7.0_79/bin/java -jar /opt/tools/picard-tools-1.139/picard.jar LiftoverVcf I=${output_path}/${NAME}_bowtie2_dupremoved_realigned_v0.1.19mpileup.vcf.gz O=${output_path}/${NAME}_liftover_v38.vcf CHAIN=${t2t_hg38_chain} REJECT=${output_path}/${NAME}_liftover_v38_rejected_variants.vcf R=${v38_ref_genome}
	/opt/tools/jdk1.7.0_79/bin/java -jar /opt/tools/picard-tools-1.139/picard.jar LiftoverVcf I=${output_path}/${NAME}_liftover_v38.vcf O=${output_path}/${NAME}_liftover_hg19.vcf CHAIN=${v38_hg19_chain} REJECT=${output_path}/${NAME}_liftover_hg19_rejected_variants.vcf R=${hg19_ref_genome}
else
	/opt/tools/jdk1.7.0_79/bin/java -jar /opt/tools/picard-tools-1.139/picard.jar LiftoverVcf I=${output_path}/${NAME}_bowtie2_dupremoved_realigned_v0.1.19mpileup.vcf.gz O=${output_path}/${NAME}_liftover_hg19.vcf CHAIN=${v38_hg19_chain} REJECT=${output_path}/${NAME}_liftover_hg19_rejected_variants.vcf R=${hg19_ref_genome}

#Samtool stats
/opt/tools/samtools-1.2/samtools stats ${output_path}/${NAME}_bowtie2_dupremoved_realigned.sorted.bam > ${output_path}/${NAME}_bowtie2_dupremoved_realigned.sorted.stats
