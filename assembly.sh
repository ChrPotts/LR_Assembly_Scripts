#!/bin/bash

# Check if a sample directory path was provided
if [ -z "$1" ]; then
    echo "Error: No sample directory path provided."
    echo "Usage: ./reassembly.sh <path_to_sample_directory> [-l] [-q] [-i] [-t]"
    echo " -l: Filter on a minimum read length {default = 10000}"
    echo " -q: Filter on a minimum average read quality score {default = 20}"
    echo " -i: Number of Flye assembly polishing iterations {default = 5}"
    echo " -t: Number of threads to utilize {default = 1}"
    echo " -g: Assumed size of the genome you are trying to assemble {default = 10Kbp}"
    echo " -m: Minimum overlap between two reads to be considered for assembly {default = 5000bp}"
    echo "Script assumes a plasmid size of ~10Kbp"
    exit 1
fi

# Default values for flags
LENGTH=10000          # Default for -l
QUALITY=20            # Default for -q
ITERATIONS=5          # Default for -i
THREADS=1             # Default for -t
GENOME_SIZE="10k"     # Default for -g
MIN_OVERLAP=5000      # Default for -m

# Store the first argument as SAMPLE_DIR
SAMPLE_DIR=$1
shift

# Parse optional arguments
while getopts "l:q:i:t:g:m:" opt; do
  case $opt in
    l) LENGTH=$OPTARG ;;        # -l argument
    q) QUALITY=$OPTARG ;;       # -q argument
    i) ITERATIONS=$OPTARG ;;    # -i argument
    t) THREADS=$OPTARG ;;       # -t argument
    g) GENOME_SIZE=$OPTARG ;;   # -g argument
    m) MIN_OVERLAP=$OPTARG ;;   # -m argument
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Verify directory exists
if [ ! -d "$SAMPLE_DIR" ]; then
    echo "Error: Directory $SAMPLE_DIR does not exist."
    exit 1
fi

# Move into the sample directory
cd "$SAMPLE_DIR" || { echo "Failed to cd into $SAMPLE_DIR"; exit 1; }

# Find fastq.gz file
FASTQ_GZ=$(ls *.fastq.gz 2>/dev/null | head -n 1)

if [ -z "$FASTQ_GZ" ]; then
    echo "Error: No .fastq.gz file found in $SAMPLE_DIR"
    exit 1
fi

# Extract SAMPLE_ID from filename (e.g., sample123.fastq.gz -> sample123)
SAMPLE_ID=$(basename "$FASTQ_GZ" .fastq.gz)

echo "Processing sample: $SAMPLE_ID"
echo "Read filtering parameters: LENGTH=$LENGTH, QUALITY=$QUALITY"
echo "Assembly polishing ITERATIONS=$ITERATIONS, THREADS=$THREADS, GENOME_SIZE=$GENOME_SIZE, MIN_OVERLAP=$MIN_OVERLAP"

# Step 1: Filter reads using NanoFilt
echo "Filtering reads..."
gunzip -c "$FASTQ_GZ" | NanoFilt -l "$LENGTH" -q "$QUALITY" > "${SAMPLE_ID}_filtered_reads.fastq"
echo "Filtered reads saved to ${SAMPLE_ID}_filtered_reads.fastq"

# Step 2: Caculate fastq read statistics using NanoPlot
echo "Calculating fastq raw read statistics using NanoPlot"
NanoPlot --fastq ${SAMPLE_ID}.fastq.gz --loglength --outdir nanoplot_raw_readquality --prefix ${SAMPLE_ID} --no_static --info_in_report

# Step 3: Caculate fastq filtered statistics using NanoPlot
echo "Calculating fastq filtered read statistics using NanoPlot"
NanoPlot --fastq ${SAMPLE_ID}_filtered_reads.fastq --loglength --outdir nanoplot_filtered_readquality --prefix ${SAMPLE_ID} --no_static --info_in_report

# Step 4: Completion message
echo "Read quality calculations completed for sample: ${SAMPLE_ID}!"
echo "All results are saved in the ${SAMPLE_ID}/nanoplot_readquality directory."

# Step 5: Assembly with Flye
ASSEMBLY_DIR="Flye_assembly"
mkdir -p "$ASSEMBLY_DIR"
echo "Running Flye..."
flye --nano-hq "${SAMPLE_ID}_filtered_reads.fastq" \
     --out-dir "$ASSEMBLY_DIR" \
     --genome-size "$GENOME_SIZE" \
     --threads "$THREADS" \
     -i "$ITERATIONS" \
     --min-overlap "$MIN_OVERLAP"

# Step 6: Alignment with minimap2
ALIGN_DIR="${ASSEMBLY_DIR}/minimap2_alignment"
mkdir -p "$ALIGN_DIR"
echo "Running minimap2..."
minimap2 -ax map-ont "${ASSEMBLY_DIR}/assembly.fasta" "${SAMPLE_ID}_filtered_reads.fastq" > "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sam"

# Step 7: SAM to BAM, sort, index, flagstat
echo "Processing BAM file..."
samtools view -S -b "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sam" > "${ALIGN_DIR}/${SAMPLE_ID}_alignment.bam"
samtools sort "${ALIGN_DIR}/${SAMPLE_ID}_alignment.bam" -o "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sorted.bam"
samtools index "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sorted.bam"
samtools flagstat "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sorted.bam" > "${ALIGN_DIR}/${SAMPLE_ID}_flagstat.txt"
samtools depth "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sorted.bam" > "${ALIGN_DIR}/${SAMPLE_ID}_read_depth.txt"

# Step 8: Extract unmapped reads
echo "Extracting unmapped reads..."
samtools view -f 4 "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sam" | awk '{print $1}' | sort | uniq > "${ALIGN_DIR}/${SAMPLE_ID}_unmapped_reads.txt"
seqkit grep -f "${ALIGN_DIR}/${SAMPLE_ID}_unmapped_reads.txt" "${SAMPLE_ID}_filtered_reads.fastq" > "${ALIGN_DIR}/${SAMPLE_ID}_unmapped_reads.fastq"

# Step 9: NanoPlot stats
echo "Running NanoPlot..."
NanoPlot --bam "${ALIGN_DIR}/${SAMPLE_ID}_alignment.sorted.bam" --loglength --outdir "${ALIGN_DIR}/nanoplot_bam_metrics" --prefix "${SAMPLE_ID}" --no_static --info_in_report

echo "Pipeline completed successfully for sample: $SAMPLE_ID"