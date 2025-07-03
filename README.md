# How to Use `reassembly.sh` and `medaka.sh` Scripts

These two scripts help you process and assemble long-read sequencing data using **NanoFilt**, **Flye**, and **Medaka**.

---

## What You Need First

1. **A folder** with your raw `.fastq.gz` file — one file per sample.
   - Example: `/Users/you/sequencing_data/SampleA/SampleA.fastq.gz`

2.  The required tools:
   - [`NanoFilt`](https://github.com/wdecoster/nanofilt)
   - [`Flye`](https://github.com/fenderglass/Flye)
   - [`minimap2`](https://github.com/lh3/minimap2)
   - [`samtools`](http://www.htslib.org/)
   - [`seqkit`](https://bioinf.shenwei.me/seqkit/)
   - [`NanoPlot`](https://github.com/wdecoster/NanoPlot)
   - [`medaka`](https://github.com/nanoporetech/medaka)

## Using Conda Environments

These scripts require different tools that are best managed using separate **conda environments**. Conda helps manage software dependencies in isolated environments to avoid version conflicts.

### Step 0: Set Up Conda (If Not Already Installed)

If you don't have conda installed, install **Miniconda** from:  
https://docs.conda.io/en/latest/miniconda.html

---

### Environment Setup (One-Time Only)

Open a terminal and run the following **once** to create the environments:

#### For `reassembly.sh`:
```bash
conda create -n contig_assembly python=3.9
conda activate contig_assembly
conda install -c bioconda nanofilt flye minimap2 samtools seqkit nanoplot
```

#### For `medaka.sh`:
```bash
conda create -n medaka_env python=3.9
conda activate medaka_env
conda install -c bioconda medaka
```

---

### Activating the Right Environment Before Running Scripts

Each time you open a new terminal or before running a script:

#### To run `reassembly.sh`, activate:

```bash
conda activate contig_assembly
./reassembly.sh /full/path/to/sample_directory
```

#### To run `medaka.sh`, activate:

```bash
conda activate medaka_env
./medaka.sh /full/path/to/sample_directory
```

You **must** activate the correct environment before running each script so that all required tools are available.

---

### Tip

You can verify the active conda environment with:

```bash
conda info --envs
```

The currently active one will have an asterisk `*` next to it.

---

---

## Step-by-Step Instructions

### Step 1: Make Scripts Executable

```bash
chmod +x reassembly.sh
chmod +x medaka.sh
```

---

### Step 2: Run the Reassembly Script

This script:
- Filters reads
- Runs Flye for assembly
- Aligns reads with minimap2
- Generates read depth & QC metrics

**Basic Command:**

```bash
./reassembly.sh /full/path/to/sample_directory
```

**With Optional Settings:**

```bash
./reassembly.sh /full/path/to/sample_directory \
  -l 12000 \        # minimum read length (default: 10000)
  -q 25 \           # minimum read quality (default: 20)
  -i 4 \            # Flye polishing iterations (default: 5)
  -t 8 \            # number of threads (default: 1)
  -g 12k \          # genome size (default: 10k)
  -m 3000           # minimum overlap (default: 5000)
```

### What You’ll Get

Inside your sample folder:
- `*_filtered_reads.fastq`
- A `Flye_assembly/` folder with assembly results
- A `Flye_assembly/minimap2_alignment/` folder with alignment files and metrics

---

### Step 3: Run the Medaka Polishing Script

After the Flye assembly is complete, run Medaka to polish the consensus.

```bash
./medaka.sh /full/path/to/sample_directory
```

Medaka will:
- Use the Flye assembly and filtered reads
- Output polished results to `Flye_assembly/Medaka_Consensus_Assembly/`

---

## Tips

- Always use the **full path** to your sample folder.
- Each sample folder must contain:
  - `your_sample.fastq.gz`
  - (after running `reassembly.sh`) `your_sample_filtered_reads.fastq`
  - `Flye_assembly/assembly.fasta`

---
## Need Help?

To see usage instructions in the terminal, just run:

```bash
./reassembly.sh
./medaka.sh
```
---

## Saving Script Output to a Log File

To record all output (both standard output and error messages) from a script into a single `.log` file, you can use the following syntax:

```bash
bash script_name.sh > output.log 2>&1
```

- `>` redirects **standard output** (stdout) to the file.
- `2>&1` ensures that **standard error** (stderr) is also redirected to the same file.

### Example:

```bash
bash assembly.sh > assembly.log 2>&1
```

This command will run `assembly.sh` and save **everything it prints**—including errors—to `assembly.log`.

** IMPORTANT WARNING **
Using the above commands will __instantly__ and __permanently__ delete any previous log files with the same pathname. If you want to run the script again, but want to preserve the results and .log file from a previous run, you should copy the starting files into a new directory. 

Most of the time, if you need to re-run the scripts, it is because the assembly didn't work the first time. In which case, re-running it with different parameters in the same directory and overwriting the previous files is desired anyway.

---

## Watching the Log File in Real Time

If you want to watch the log file as it's being written to (for example, to monitor progress or catch errors as they occur), use the `tail` command with the `-f` (follow) flag:

```bash
tail -f output.log
```

You can stop watching the log at any time by pressing `Ctrl + C`.

---

## Opening Log Files in the Terminal

Once a run is complete, and you want to open a log filr, use the `less` command:

```bash
less output.log
```

---
