#Download SRA files
for srr in $(cat srr_list.txt); do
    prefetch $srr
done

#Convert .sra to .fastq using fasterq-dump
fasterq-dump SRRXXXXX --split-files

#List fastq files
ls *.fastq

#Run FastQC
fastqc *.fastq

#Run MultiQC
multiqc .

#Trim adapters using Trimmomatic
trimmomatic PE R1.fastq R2.fastq \
R1_paired.fastq R1_unpaired.fastq \
R2_paired.fastq R2_unpaired.fastq \
LEADING:3 TRAILING:3 SLIDINGWINDOW:4:20 MINLEN:36

#Run FastQC again on trimmed files
fastqc *_paired.fastq

#Import into QIIME2 with manifest (PairedEnd, Phred33V2)
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path manifest.tsv \
  --output-path paired-end-demux.qza \
  --input-format PairedEndFastqManifestPhred33V2

#Summarize demux
qiime demux summarize \
  --i-data paired-end-demux.qza \
  --o-visualization paired-end-demux.qzv

#Run DADA2
qiime dada2 denoise-paired \
  --i-demultiplexed-seqs paired-end-demux.qza \
  --p-trunc-len-f 250 \
  --p-trunc-len-r 200 \
  --p-trim-left-f 10 \
  --p-trim-left-r 10 \
  --o-table table.qza \
  --o-representative-sequences rep-seqs.qza \
  --o-denoising-stats denoising-stats.qza

#Summaries
#qiime feature-table summarize
qiime feature-table summarize \
  --i-table table.qza \
  --o-visualization table.qzv \
  --m-sample-metadata-file metadata.tsv

#qiime feature-table tabulate-seqs
qiime feature-table tabulate-seqs \
  --i-data rep-seqs.qza \
  --o-visualization rep-seqs.qzv

#qiime metadata tabulate
qiime metadata tabulate \
  --m-input-file denoising-stats.qza \
  --o-visualization denoising-stats.qzv

#Taxonomy classification
qiime feature-classifier classify-sklearn \
  --i-classifier silva-138-99-nb-classifier.qza \
  --i-reads rep-seqs.qza \
  --o-classification taxonomy.qza

#Alpha Diversity
qiime feature-table rarefy \
  --i-table table.qza \
  --p-sampling-depth 1000 \
  --o-rarefied-table table_rarefied_1000.qza

#Observed Features
qiime diversity alpha \
  --i-table table_rarefied_1000.qza \
  --p-metric observed_features \
  --o-alpha-diversity observed_features_vector.qza

#Shannon Diversity
qiime diversity alpha \
  --i-table table_rarefied_1000.qza \
  --p-metric shannon \
  --o-alpha-diversity shannon_vector.qza

#Evenness
qiime diversity alpha \
  --i-table table_rarefied_1000.qza \
  --p-metric pielou_evenness \
  --o-alpha-diversity evenness_vector.qza

#Faith’s Phylogenetic Diversity
qiime diversity alpha-phylogenetic \
  --i-table table_rarefied_1000.qza \
  --i-phylogeny rooted-tree.qza \
  --p-metric faith_pd \
  --o-alpha-diversity faith_pd_vector.qza

#Alpha Group Significance
qiime diversity alpha-group-significance \
  --i-alpha-diversity shannon_vector.qza \
  --m-metadata-file metadata.tsv \
  --o-visualization shannon_group_significance.qzv

#Beta Diversity core metrics
qiime diversity core-metrics-phylogenetic \
  --i-table table.qza \
  --i-phylogeny rooted-tree.qza \
  --p-sampling-depth 1000 \
  --m-metadata-file metadata.tsv \
  --output-dir core_metrics_1000
