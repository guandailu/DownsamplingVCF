#!/bin/bash -l

set -e

####################################
#
#   Randomly subset SNPs from vcfs
#   Author: Dailu Guan
#   Date: July 30, 2022
#
####################################

usage(){
  echo "Usage: $0 [vcf] [subset_num_snps] [output_file]
                  [vcf]: vcf file to be subsetted
                  [subset_num_snps]: number of SNPs to be randomly removed
                  [snp_list_file]: output file with downsampled SNPs
		  [output_file]: output vcf file name " 1>&2
}
exit_abnormal(){
  usage
  exit 1
}

vcf=$1
subset_num_snps=$2
snp_list_file=$3
output_file=$4
module load bcftools

if [[ $# -ne 4 ]]
then
    echo "Error: Inputs incorrect !!!"
    exit_abnormal
    exit 1
fi

# Create temporary directory
mkdir -p Temp

# compress vcf file
if [[ ${vcf##*.} == "vcf" ]]
then
  bgzip ${vcf}
  vcf=${vcf}.gz
else
  vcf=${vcf}
fi
echo -e "VCF file is: ${vcf}\n"

# index vcf
if [[ ! -f ${vcf}.tbi ]]
then
  tabix -p vcf -f ${vcf}
fi

# Calculate total number of SNPs
num_snps=`zcat ${vcf} |  grep -v "#" | wc -l`

# index of removed SNPs
TMP_FILE="$(mktemp Temp/XXXXXXXXXX)"
shuf -i 1-${num_snps} -n ${subset_num_snps} | sort -k1,1n > ${TMP_FILE}

# subset snps
TMP_FILE2=$(mktemp Temp/XXXXXXXXXX)
zcat ${vcf} | grep -v "#" | awk 'FNR==NR{a[$1];next}(FNR in a){print $1"\t"$2}' ${TMP_FILE} - > ${TMP_FILE2}
cp ${TMP_FILE2} ${snp_list_file}
#Temp/${vcf}.subsetting_${subset_num_snps}.list

# subset SNPs
echo -e "Generating subsetting vcf...\n"
if [[ ${output_file} =~ ".gz$" ]]
then
  output_file=${output_file}
else
  output_file=${output_file}.gz
fi
vcftools --gzvcf ${vcf} --exclude-positions ${TMP_FILE2} --recode --recode-INFO-all --stdout | bgzip -c > ${output_file}
tabix -p vcf -f ${output_file}

if [[ -s ${output_file} ]]
then
  rm -rf ${TMP_FILE} ${TMP_FILE2}
fi

echo -e "All done !!!\n"
