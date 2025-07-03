#!/bin/bash

# Check if a sample directory path was provided
if [ -z "$1" ]; then
    echo "Error: No sample directory path provided."
    echo "Usage: ./medaka.sh <path_to_sample_directory>"
    exit 1
fi

# Store the argument as SAMPLE_DIR and validate
SAMPLE_DIR=$1

if [ ! -d "$SAMPLE_DIR" ]; then
    echo "Error: Directory $SAMPLE_DIR does not exist."
    exit 1
fi

# Move into the sample directory
cd "$SAMPLE_DIR" || { echo "Failed to cd into $SAMPLE_DIR"; exit 1; }

# Find the sample ID by looking for a .fastq.gz file
FASTQ_GZ=$(ls *.fastq.gz 2>/dev/null | head -n 1)
if [ -z "$FASTQ_GZ" ]; then
    echo "Error: No .fastq.gz file found in $SAMPLE_DIR"
    exit 1
fi
SAMPLE_ID=$(basename "$FASTQ_GZ" .fastq.gz)

# Run Medaka
echo "Refining Flye assembly with Medaka for ${SAMPLE_ID}"
medaka_consensus \
    -d Flye_assembly/assembly.fasta \
    -i ${SAMPLE_ID}_filtered_reads.fastq \
    -o Flye_assembly/Medaka_Consensus_Assembly

# Completion message
echo "Medaka consensus for ${SAMPLE_ID} saved to Flye_assembly/Medaka_Consensus_Assembly"