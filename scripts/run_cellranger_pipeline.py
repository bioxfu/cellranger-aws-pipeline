# # Single Sample Pipeline
# ###########################################
# from common_utils.s3_utils import download_file, upload_file, download_folder, upload_folder
# from common_utils.job_utils import generate_working_dir, delete_working_dir

import re
import yaml
import pandas as pd
import glob
import json
import sys
import boto3
import botocore
import os
import shlex
import subprocess
from common_utils.s3_utils import download_file, upload_file, download_folder, upload_folder
from common_utils.job_utils import generate_working_dir, delete_working_dir

# check available disk space
cmd = 'df -h'
subprocess.check_call(shlex.split(cmd))

directory = 'scratch'
if not os.path.exists(directory):
    os.makedirs(directory)

# move into scratch directory
os.chdir('scratch')

################## TODO ###################
1. Download 





###########################################

# Copy files from S3
###########################################

# refdata
bucket = '10x-pipeline'
# s3_folder = 'reference_transcriptome'
# version = '1.2.0'
# ref_trans = 'GRCh38'
# s3_path = f"s3://{bucket}/{s3_folder}/{version}"
# download_folder(s3_path, ref_trans)

# tiny-bcl
# TODO: change so that we are dealing with tar.gz raw_data
s3_folder = 'tiny-bcl'
s3_path = f"s3://{bucket}/{s3_folder}/raw_data"
download_folder(s3_path, 'raw_data')

# check refdata
# cmd = f"ls -l {ref_trans}"
# subprocess.check_call(shlex.split(cmd))

# Run Cellranger MKFASTQ and COUNT
############################################

# # cellranger mkfastqs
# cmd = 'cellranger mkfastq --id=tiny-bcl-output --run=tiny-bcl/cellranger-tiny-bcl-1.2.0/ --csv=tiny-bcl/cellranger-tiny-bcl-samplesheet-1.2.0.csv'
# subprocess.check_call(shlex.split(cmd))

# #
# # use full path for reference transcriptome
# #

# # cellranger count
# cmd = 'cellranger count --id=test_sample --fastqs=tiny-bcl-output/outs/fastq_path/p1/s1 --sample=test_sample --expect-cells=1000 --localmem=3 --chemistry=SC3Pv2 --transcriptome=refdata-cellranger-GRCh38-1.2.0'
# subprocess.check_call(shlex.split(cmd))


# # # Copy data back to S3
# # ###########################

# # copy mkfastq outputs
# s3_path = 's3://' + bucket + '/tiny-bcl-output'
# fcs_files_path = 'tiny-bcl-output'
# upload_folder(s3_path, fcs_files_path)

# # copy count outputs
# s3_path = 's3://' + bucket + '/test_sample'
# fcs_files_path = 'test_sample'
# upload_folder(s3_path, fcs_files_path)