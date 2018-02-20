# Cellranger AWS Pipeline

  This repo is working towards deploying the 10X cellranger pipeline on AWS. In a separate repo, [dockerized-cellranger](https://github.com/ismms-himc/dockerized_cellranger), we ran `cellranger mkfastq` and `cellranger count` in a docker container using the `tiny-bcl` example dataset (the image ran successfully on linux but not on mac). However, the reference transcriptome (e.g. GRCh38) was included in the docker iamge, which made the image ~18GB and this is too large to run on AWS batch. We are working on a docker image that uses `boto` to copy the reference from S3 to a 1TB mounted volume (see `docker_scratch` below).

  Currently, we can get several jobs to run and share the same `docker_scratch` directory and have access to up to 64GB of memory. Next, we are working on getting jobs to run `cellranger mkfastq` and `cellranger count`.

  ### To Do
  * get jobs to write to different directories within the 1TB `docker_scratch` directory
  * set up python script to actually run the cellranger commands
  * save cellranger outputs back to S3 bucket
  * step-1: download primary bcl data and reference transcriptome
  * step-2: single job that runs `cellranger mkfastq` on tiny-bcl data
  * step-3: single job that runs `cellranger count` on tiny-bcl fastqs
  * ~~test running jobs with higher memory requirements, we need ~30-60GB~~

The steps required to submit jobs to AWS batch are discussed below.

# 1. Build Stack using Cloudformation

  The following commands can be used to create and update the stack on AWS using the `cf_cellranger.json` cloudformation

  `$ aws cloudformation create-stack --template-body file://cf_cellranger.json --stack-name cellranger-job --capabilities CAPABILITY_NAMED_IAM`

  `$ aws cloudformation update-stack --template-body file://cf_cellranger.json --stack-name cellranger-job --capabilities CAPABILITY_NAMED_IAM`

  The cloudformation template sets up the mounted volume for the jobs (see jobdefinition in template) and tells batch to use a custom AMI that has a mounted 1TB volume for the compute environment. See [aws-batch-genomics](https://aws.amazon.com/blogs/compute/building-high-throughput-genomic-batch-workflows-on-aws-batch-layer-part-3-of-4/) part 3 to see how to make a custom AMI. Also see the [cloudformation docs](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-batch-computeenvironment.html) for an exmaple of how to use a custom AMI as a compute environment for AWS batch. Additional helpful links:

    * [aws London pop-up video batch computing](https://www.youtube.com/watch?v=H8bmHU_z8Ac&t=662s)
    * [base2 genomics presentation for AWS re:invent](https://www.youtube.com/watch?v=8dApnlJLY54&t=2785s)

# 2. Upload reference data to S3

  Upload `refdata-cellranger-GRCh38-1.2.0` to S3 (~16GB) using `common_utils`. This reference is not in the repo and the upload was done elsewhere.


# 3. Make and Run Docker Image that will be used as the Batch Job Definition
  Use the following docker commands to build and run the container. See the next section for the commands to run within the contianer.

  `$ docker build -t <URI>.dkr.ecr.us-east-1.amazonaws.com/awsbatch/cellranger-aws-pipeline .`

  `$ docker run -it --rm -p 8087:80 <URI>.dkr.ecr.us-east-1.amazonaws.com/awsbatch/cellranger-aws-pipeline`

# 4. Push Image to AWS ECS

  After the image has been built it needs to be pushed to AWS ECS. First auth credentials need to be obtained by running

  `$ aws ecr get-login`

  This will return a long aws CLI command that you need to copy and paste into the terminal. You may need to remove `-e none` from the command if docker gives an error. Now that you have the proper credentials, you will be able to push the repository using the following command:

  `$ docker push <URI>.dkr.ecr.us-east-1.amazonaws.com/awsbatch/cellranger-aws-pipeline`

# 5. Run Cellranger Commands in Container (in-progress)

  These are the Cellranger commands that need to be run in the container. They will be run by `run_cellranger_pipeline.py`, which currently only copies the reference genome from S3.

  ### Cellranger mkfastq
  `$ cellranger mkfastq --id=tiny-bcl-output --run=/tiny-bcl/cellranger-tiny-bcl-1.2.0/ --csv=/tiny-bcl/cellranger-tiny-bcl-samplesheet-1.2.0.csv`

  ### Cellranger count
  `$ cellranger count --id=test_sample --fastqs=/tiny-bcl-output/outs/fastq_path/p1/s1 --sample=test_sample --expect-cells=1000 --transcriptome=/refdata-cellranger-GRCh38-1.2.0`


# System Requirements (from [10X Genomics](https://support.10xgenomics.com/single-cell-gene-expression/software/overview/system-requirements))

System Requirements
Cell Ranger
Cell Ranger pipelines run on Linux systems that meet these minimum requirements:

8-core Intel or AMD processor (16 recommended)
64GB RAM (128GB recommended)
1TB free disk space
64-bit CentOS/RedHat 5.5 or Ubuntu 10.04
The pipelines also run on clusters that meet these minimum requirements:

8-core Intel or AMD processor per node
6GB RAM per core
Shared filesystem (e.g. NFS)
SGE or LSF
In addition, Cell Ranger must be run on a system with the following software pre-installed:

Illumina bcl2fastq
bcl2fastq 2.17 or higher is preferred and supports most sequencers running RTA version 1.18.54 or higher. If you are using a NovaSeq, please use version 2.20 or higher. If your sequencer is running an older version of RTA, then bcl2fastq 1.8.4 is required by Illumina.

All other software dependencies come bundled in the Cell Ranger package.

# Components

Modified from from dockerfile: https://hub.docker.com/r/litd/docker-cellranger/

10X Genomics Cell Ranger Suite

bcl2fastq2 v2.19 (06/13/2017)

cellranger v2.1.0